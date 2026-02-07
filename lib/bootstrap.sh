#!/bin/bash
#------------------------------------------------------------------------------
# BOOTSTRAP - Download i18n and lib systems from GitHub
#------------------------------------------------------------------------------

# Ensure BRANCH is set
BRANCH="${BRANCH:-main}"

# Base URL for downloads
_BOOTSTRAP_BASE_URL="${OHMYTERMUX_REPO_URL:-https://raw.githubusercontent.com/devohmycode/OhMyTermux}/$BRANCH"

#------------------------------------------------------------------------------
# Verify downloaded file checksum
#------------------------------------------------------------------------------
verify_download() {
    local FILE_PATH="$1"
    local EXPECTED_HASH="$2"

    if [ -z "$EXPECTED_HASH" ]; then
        return 0
    fi

    if ! command -v sha256sum &>/dev/null; then
        echo "Warning: sha256sum not available, skipping checksum verification" >&2
        return 0
    fi

    local ACTUAL_HASH
    ACTUAL_HASH=$(sha256sum "$FILE_PATH" 2>/dev/null | cut -d' ' -f1)

    if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
        echo "Error: Checksum mismatch for $FILE_PATH" >&2
        echo "  Expected: $EXPECTED_HASH" >&2
        echo "  Got:      $ACTUAL_HASH" >&2
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Generic file download function
#------------------------------------------------------------------------------
_download_files() {
    local BASE_DIR="$1"
    shift
    local FILES=("$@")

    for FILE in "${FILES[@]}"; do
        local URL="$_BOOTSTRAP_BASE_URL/$FILE"
        local LOCAL_PATH="$BASE_DIR/$FILE"
        local LOCAL_DIR=$(dirname "$LOCAL_PATH")

        mkdir -p "$LOCAL_DIR"

        if ! curl -fL -s -o "$LOCAL_PATH" "$URL" 2>/dev/null; then
            echo "Warning: Could not download $FILE from $URL" >&2
            return 1
        fi
    done

    return 0
}

#------------------------------------------------------------------------------
# Download the i18n system if needed
#------------------------------------------------------------------------------
download_i18n_system() {
    local I18N_FILES=(
        "i18n/i18n.sh"
        "i18n/locale_detect.sh"
        "i18n/messages/en.sh"
        "i18n/messages/fr.sh"
    )

    mkdir -p "$SCRIPT_DIR/i18n/messages"
    _download_files "$SCRIPT_DIR" "${I18N_FILES[@]}"
}

#------------------------------------------------------------------------------
# Download the lib system if needed
#------------------------------------------------------------------------------
download_lib_system() {
    local LIB_FILES=(
        "lib/i18n_loader.sh"
        "lib/common.sh"
        "lib/constants.sh"
        "lib/colors.sh"
        "lib/messages.sh"
        "lib/logging.sh"
        "lib/execute.sh"
        "lib/gum_ui.sh"
        "lib/banner.sh"
    )

    mkdir -p "$SCRIPT_DIR/lib"
    _download_files "$SCRIPT_DIR" "${LIB_FILES[@]}"
}
