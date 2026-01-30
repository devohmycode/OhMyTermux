#!/bin/bash
#------------------------------------------------------------------------------
# ERROR LOGGING
#------------------------------------------------------------------------------
log_error() {
    local ERROR_MSG="$1"
    local USERNAME=$(whoami)
    local HOSTNAME=$(hostname)
    local CWD=$(pwd)
    echo "[$(date +'%d/%m/%Y %H:%M:%S')] ERROR: $ERROR_MSG | User: $USERNAME | Host: $HOSTNAME | Directory: $CWD" >> "$HOME/.config/OhMyTermux/install.log"
}
