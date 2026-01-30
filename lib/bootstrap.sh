#!/bin/bash
#------------------------------------------------------------------------------
# BOOTSTRAP - Download i18n and lib systems from GitHub
#------------------------------------------------------------------------------

# Ensure BRANCH is set
BRANCH="${BRANCH:-main}"

# Base URL for downloads
_BOOTSTRAP_BASE_URL="https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH"

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

        if ! curl -L -s -o "$LOCAL_PATH" "$URL" 2>/dev/null; then
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
        "lib/common.sh"
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
