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
#   VERBOSE          - If "true", show bootstrap progress messages
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Expected version of the i18n message files
#------------------------------------------------------------------------------
# Bump this whenever i18n/messages/*.sh change, and set MSG_I18N_VERSION to the
# same value in en.sh and fr.sh. Cached copies carrying any other value are
# re-downloaded. This is a content marker, not a branch name: BRANCH tracks a
# rolling branch and no longer changes when the messages do.
I18N_EXPECTED_VERSION="${I18N_EXPECTED_VERSION:-1.2.2}"

#------------------------------------------------------------------------------
# Script validation function
#------------------------------------------------------------------------------
_validate_script() { head -1 "$1" 2>/dev/null | grep -q "^#!/bin/bash"; }

#------------------------------------------------------------------------------
# Progress messages: silent unless verbose mode is requested
#------------------------------------------------------------------------------
# The caller's arguments are still visible here because this file is sourced
# without arguments, and arguments are parsed later in the calling script.
_i18n_verbose=false
if [ "$VERBOSE" = "true" ] || [ "$OHMYTERMUX_VERBOSE" = "true" ]; then
    _i18n_verbose=true
else
    for _arg in "$@"; do
        case "$_arg" in
            --verbose|-v) _i18n_verbose=true; break ;;
        esac
    done
    unset _arg
fi

_i18n_info() { [ "$_i18n_verbose" = "true" ] && echo "$1" >&2; return 0; }

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
    _i18n_info "Initializing i18n system..."
    if download_i18n_system && _validate_script "$SCRIPT_DIR/i18n/i18n.sh"; then
        _i18n_info "i18n system downloaded and loaded successfully."
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
#------------------------------------------------------------------------------
# MSG_I18N_VERSION in each message file must match I18N_EXPECTED_VERSION; if not,
# en.sh and fr.sh are re-downloaded from BRANCH. The marker is deliberately
# independent of BRANCH, which tracks a rolling branch and therefore no longer
# signals that message content changed.
_message_file_version() {
    grep '^MSG_I18N_VERSION=' "$1" 2>/dev/null | head -1 | cut -d'"' -f2
}

_check_and_refresh_messages() {
    local _needs_refresh=false
    local _lang _file _version

    for _lang in en fr; do
        _file="$SCRIPT_DIR/i18n/messages/${_lang}.sh"
        # A missing file always needs a refresh
        if [ ! -f "$_file" ]; then
            _needs_refresh=true
            break
        fi
        _version=$(_message_file_version "$_file")
        if [ -z "$_version" ] || [ "$_version" != "$I18N_EXPECTED_VERSION" ]; then
            _needs_refresh=true
            break
        fi
    done

    [ "$_needs_refresh" = "true" ] || return 0

    _i18n_info "Refreshing i18n messages (expected version: $I18N_EXPECTED_VERSION)..."
    mkdir -p "$SCRIPT_DIR/i18n/messages"
    local _base_url="${_BOOTSTRAP_BASE_URL:-https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH}"
    local _tmp
    for _lang in en fr; do
        _file="$SCRIPT_DIR/i18n/messages/${_lang}.sh"
        _tmp=$(mktemp 2>/dev/null || echo "${_file}.tmp")
        # Download to a temporary file so a failed fetch never destroys a
        # working copy of the messages
        if curl -fL -s -o "$_tmp" "$_base_url/i18n/messages/${_lang}.sh" 2>/dev/null \
            && _validate_script "$_tmp"; then
            mv "$_tmp" "$_file"
        else
            rm -f "$_tmp" 2>/dev/null
            _i18n_info "Warning: could not refresh i18n/messages/${_lang}.sh, keeping the local copy."
        fi
    done
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
