#!/bin/bash
#------------------------------------------------------------------------------
# I18N LOADER - Centralized i18n and lib loading system
#------------------------------------------------------------------------------
# This script centralizes the bootstrap, i18n download/load, and lib loading
# logic that was previously duplicated across install.sh, xfce.sh, proot.sh,
# and utils.sh.
#
# Usage:
#   source "$SCRIPT_DIR/lib/i18n_loader.sh"
#
# Required variables (must be set before sourcing):
#   SCRIPT_DIR - Root directory of the project
#   BRANCH     - GitHub branch for downloads
#
# Optional variables:
#   OVERRIDE_LANG    - Language override (e.g., "fr")
#   I18N_DEFER_INIT  - If "true", skip init_i18n() call (caller handles it)
#   I18N_SKIP_LIB    - If "true", skip loading lib/common.sh
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Script validation function
#------------------------------------------------------------------------------
_validate_script() { head -1 "$1" 2>/dev/null | grep -q "^#!/bin/bash"; }

#------------------------------------------------------------------------------
# Download and load bootstrap.sh
#------------------------------------------------------------------------------
_bootstrap_url="https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/lib/bootstrap.sh"

mkdir -p "$SCRIPT_DIR/lib"
if [ ! -f "$SCRIPT_DIR/lib/bootstrap.sh" ] || ! _validate_script "$SCRIPT_DIR/lib/bootstrap.sh"; then
    curl -fL -s -o "$SCRIPT_DIR/lib/bootstrap.sh" "$_bootstrap_url" 2>/dev/null
    if ! _validate_script "$SCRIPT_DIR/lib/bootstrap.sh"; then
        echo "Error: Failed to download bootstrap.sh from $_bootstrap_url" >&2
        exit 1
    fi
fi
source "$SCRIPT_DIR/lib/bootstrap.sh"

#------------------------------------------------------------------------------
# Download and load i18n system
#------------------------------------------------------------------------------
if [ ! -f "$SCRIPT_DIR/i18n/i18n.sh" ] || ! _validate_script "$SCRIPT_DIR/i18n/i18n.sh"; then
    echo "Initializing i18n system..." >&2
    if download_i18n_system && _validate_script "$SCRIPT_DIR/i18n/i18n.sh"; then
        echo "i18n system downloaded and loaded successfully." >&2
    else
        echo "Error: Could not download i18n system. Using fallback messages." >&2
        t() {
            local key="$1"
            local default="$2"
            local val="${!key}"
            echo "${val:-${default:-$key}}"
        }
        init_i18n() { return 0; }
        MESSAGES_LOADED="fallback"
    fi
fi

#------------------------------------------------------------------------------
# Refresh message files if they are outdated (version mismatch)
# MSG_I18N_VERSION must match BRANCH; if not, re-download en.sh and fr.sh
#------------------------------------------------------------------------------
_check_and_refresh_messages() {
    local _expected_version="${BRANCH}"
    local _en_file="$SCRIPT_DIR/i18n/messages/en.sh"
    local _needs_refresh=false

    # If message files don't exist, refresh is needed
    if [ ! -f "$_en_file" ]; then
        _needs_refresh=true
    else
        # Source only the version variable to check it without polluting the env
        local _current_version
        _current_version=$(grep '^MSG_I18N_VERSION=' "$_en_file" 2>/dev/null | head -1 | cut -d'"' -f2)
        if [ -z "$_current_version" ] || [ "$_current_version" != "$_expected_version" ]; then
            _needs_refresh=true
        fi
    fi

    if [ "$_needs_refresh" = "true" ]; then
        mkdir -p "$SCRIPT_DIR/i18n/messages"
        local _base_url="${_BOOTSTRAP_BASE_URL:-https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH}"
        for _lang in en fr; do
            curl -fL -s -o "$SCRIPT_DIR/i18n/messages/${_lang}.sh" \
                "$_base_url/i18n/messages/${_lang}.sh" 2>/dev/null || true
        done
    fi
}

if [ "${MESSAGES_LOADED}" != "fallback" ]; then
    _check_and_refresh_messages
fi

if [ -f "$SCRIPT_DIR/i18n/i18n.sh" ] && _validate_script "$SCRIPT_DIR/i18n/i18n.sh"; then
    source "$SCRIPT_DIR/i18n/i18n.sh"
fi

# Initialize i18n immediately unless deferred
if [ "${I18N_DEFER_INIT}" != "true" ]; then
    type init_i18n &>/dev/null && init_i18n "$OVERRIDE_LANG"
fi

#------------------------------------------------------------------------------
# Download and load lib system
#------------------------------------------------------------------------------
if [ "${I18N_SKIP_LIB}" != "true" ]; then
    if [ ! -f "$SCRIPT_DIR/lib/common.sh" ] || ! _validate_script "$SCRIPT_DIR/lib/common.sh"; then
        download_lib_system
    fi
    source "$SCRIPT_DIR/lib/common.sh"
fi
