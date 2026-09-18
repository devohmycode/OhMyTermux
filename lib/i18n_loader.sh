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
# Version of the cached files
#------------------------------------------------------------------------------
# Everything under lib/, i18n/ and presets/ is downloaded once and then kept, so
# a cached copy would otherwise never pick up a fix. Bump this whenever any of
# those files change: this loader is re-downloaded on every run, so the new
# value reaches users immediately and forces the stale copies to be refreshed.
# MSG_I18N_VERSION in i18n/messages/*.sh must carry the same value.
#
# A content marker, not a branch name: BRANCH tracks a rolling branch and no
# longer changes when the content does.
OHMYTERMUX_CACHE_VERSION="${OHMYTERMUX_CACHE_VERSION:-1.2.3}"

# Records the version the cached files were downloaded at
_cache_stamp="$SCRIPT_DIR/.ohmytermux-cache"
_cache_is_stale=false
_cache_refresh_failed=false
if [ ! -f "$_cache_stamp" ] \
    || [ "$(cat "$_cache_stamp" 2>/dev/null)" != "$OHMYTERMUX_CACHE_VERSION" ]; then
    _cache_is_stale=true
fi

#------------------------------------------------------------------------------
# Script validation function
#------------------------------------------------------------------------------
_validate_script() { head -1 "$1" 2>/dev/null | grep -q "^#!/bin/bash"; }

#------------------------------------------------------------------------------
# Download a single file, keeping the local copy if the download fails
#------------------------------------------------------------------------------
_refresh_file() {
    local _dest="$1"
    local _url="$2"
    local _tmp
    _tmp=$(mktemp 2>/dev/null || echo "${_dest}.tmp")
    if curl -fL -s -o "$_tmp" "$_url" 2>/dev/null && _validate_script "$_tmp"; then
        mv "$_tmp" "$_dest"
        return 0
    fi
    rm -f "$_tmp" 2>/dev/null
    return 1
}

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
_bootstrap_url="${OHMYTERMUX_REPO_URL:-https://raw.githubusercontent.com/devohmycode/OhMyTermux}/$BRANCH/lib/bootstrap.sh"

mkdir -p "$SCRIPT_DIR/lib"
if [ ! -f "$SCRIPT_DIR/lib/bootstrap.sh" ] || ! _validate_script "$SCRIPT_DIR/lib/bootstrap.sh"; then
    if ! _refresh_file "$SCRIPT_DIR/lib/bootstrap.sh" "$_bootstrap_url"; then
        echo "Error: Failed to download bootstrap.sh from $_bootstrap_url" >&2
        exit 1
    fi
elif [ "$_cache_is_stale" = "true" ]; then
    # A valid copy is already there, so a failed refresh is not fatal
    if ! _refresh_file "$SCRIPT_DIR/lib/bootstrap.sh" "$_bootstrap_url"; then
        _i18n_info "Warning: could not refresh lib/bootstrap.sh, keeping the local copy."
        _cache_refresh_failed=true
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
elif [ "$_cache_is_stale" = "true" ]; then
    _i18n_info "Refreshing i18n system..."
    if ! download_i18n_system; then
        _i18n_info "Warning: could not refresh the i18n system, keeping the local copy."
        _cache_refresh_failed=true
    fi
fi

#------------------------------------------------------------------------------
# Refresh message files if they are outdated (version mismatch)
#------------------------------------------------------------------------------
# MSG_I18N_VERSION in each message file must match OHMYTERMUX_CACHE_VERSION; if
# not, en.sh and fr.sh are re-downloaded from BRANCH. Checking the marker inside
# the files complements the stamp file: it catches a message file that is stale
# on its own, whatever the stamp claims.
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
        if [ -z "$_version" ] || [ "$_version" != "$OHMYTERMUX_CACHE_VERSION" ]; then
            _needs_refresh=true
            break
        fi
    done

    [ "$_needs_refresh" = "true" ] || return 0

    _i18n_info "Refreshing i18n messages (expected version: $OHMYTERMUX_CACHE_VERSION)..."
    mkdir -p "$SCRIPT_DIR/i18n/messages"
    local _base_url="${_BOOTSTRAP_BASE_URL:-https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH}"
    for _lang in en fr; do
        _file="$SCRIPT_DIR/i18n/messages/${_lang}.sh"
        if ! _refresh_file "$_file" "$_base_url/i18n/messages/${_lang}.sh"; then
            _i18n_info "Warning: could not refresh i18n/messages/${_lang}.sh, keeping the local copy."
            _cache_refresh_failed=true
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
    elif [ "$_cache_is_stale" = "true" ]; then
        _i18n_info "Refreshing lib system..."
        if ! download_lib_system; then
            _i18n_info "Warning: could not refresh the lib system, keeping the local copy."
            _cache_refresh_failed=true
        fi
    fi
    source "$SCRIPT_DIR/lib/common.sh"
fi

#------------------------------------------------------------------------------
# Record the version the cached files now come from
#------------------------------------------------------------------------------
# Only once every refresh succeeded, so a run interrupted by a network failure
# retries next time instead of marking a half-updated cache as current. Skipped
# when the caller opted out of the lib system, which stays at its old version.
if [ "$_cache_is_stale" = "true" ] \
    && [ "$_cache_refresh_failed" != "true" ] \
    && [ "${I18N_SKIP_LIB}" != "true" ]; then
    printf '%s\n' "$OHMYTERMUX_CACHE_VERSION" > "$_cache_stamp" 2>/dev/null || true
fi
