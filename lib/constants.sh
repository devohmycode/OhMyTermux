#!/bin/bash
#------------------------------------------------------------------------------
# PROJECT CONSTANTS
#------------------------------------------------------------------------------

# Paths
PROOT_DEBIAN_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
OHMYTERMUX_CONFIG_DIR="$HOME/.config/OhMyTermux"
OHMYTERMUX_REPO_URL="https://raw.githubusercontent.com/devohmycode/OhMyTermux"

# UI constants
GUM_DEFAULT_WIDTH=42
BANNER_HEIGHT=7
SHELL_MENU_HEIGHT=7

# Validation constants
USERNAME_REGEX='^[a-z_][a-z0-9_-]{0,31}$'
PASSWORD_MIN_LENGTH=4

#------------------------------------------------------------------------------
# INPUT VALIDATION
#------------------------------------------------------------------------------
validate_username() {
    local USERNAME="$1"
    if [ -z "$USERNAME" ]; then
        echo "Username cannot be empty." >&2
        return 1
    fi
    if ! [[ "$USERNAME" =~ $USERNAME_REGEX ]]; then
        echo "Invalid username. Must start with a lowercase letter or underscore, contain only lowercase letters, digits, underscores or hyphens, and be at most 32 characters." >&2
        return 1
    fi
    return 0
}

validate_password() {
    local PASSWORD="$1"
    if [ -z "$PASSWORD" ]; then
        echo "Password cannot be empty." >&2
        return 1
    fi
    if [ ${#PASSWORD} -lt $PASSWORD_MIN_LENGTH ]; then
        echo "Password must be at least $PASSWORD_MIN_LENGTH characters." >&2
        return 1
    fi
    if [[ "$PASSWORD" =~ [\`\$\"\'\\\!] ]]; then
        echo "Password contains characters that may cause issues with the shell." >&2
        return 1
    fi
    return 0
}
