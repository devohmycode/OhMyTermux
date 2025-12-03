#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GitHub branch for downloads
BRANCH="main"

# Language override variable
OVERRIDE_LANG=""

# Global variables
USE_GUM=false
VERBOSE=false
INSTALL_THEME=false
INSTALL_ICONS=false
INSTALL_WALLPAPERS=false
INSTALL_CURSORS=false
SELECTED_THEME=""
SELECTED_ICON_THEME=""
SELECTED_WALLPAPER=""

# PROOT VARIABLES
PROOT_USERNAME=""
PROOT_PASSWORD=""

#------------------------------------------------------------------------------
# PRELIMINARY ARGUMENT PARSING FOR LANGUAGE
#------------------------------------------------------------------------------
for ARG in "$@"; do
    case $ARG in
        --lang|-l)
            shift
            if [ -n "$1" ]; then
                OVERRIDE_LANG="$1"
                shift
            else
                echo "Error: --lang requires an argument (ex: --lang fr)" >&2
                exit 1
            fi
            ;;
        *)
            ;;
    esac
done

# Function to download the i18n system if necessary
download_i18n_system() {
    local BASE_URL="https://raw.githubusercontent.com/GiGiDKR/OhMyTermux/$BRANCH"
    local TEMP_I18N_DIR="$SCRIPT_DIR/i18n"
    local TEMP_MESSAGES_DIR="$TEMP_I18N_DIR/messages"

    # Create temporary directories
    mkdir -p "$TEMP_MESSAGES_DIR"

    # List of i18n files to download
    local I18N_FILES=(
        "i18n/i18n.sh"
        "i18n/locale_detect.sh"
        "i18n/messages/en.sh"
        "i18n/messages/fr.sh"
    )

    # Download each file
    for FILE in "${I18N_FILES[@]}"; do
        local URL="$BASE_URL/$FILE"
        local LOCAL_PATH="$SCRIPT_DIR/$FILE"
        local LOCAL_DIR=$(dirname "$LOCAL_PATH")

        # Create the directory if necessary
        mkdir -p "$LOCAL_DIR"

        # Download the file
        if ! curl -L -s -o "$LOCAL_PATH" "$URL" 2>/dev/null; then
            echo "Warning: Could not download $FILE from $URL" >&2
            return 1
        fi
    done

    return 0
}

if [ -f "$SCRIPT_DIR/i18n/i18n.sh" ]; then
    source "$SCRIPT_DIR/i18n/i18n.sh"
    init_i18n "$OVERRIDE_LANG"
else
    echo "Initializing i18n system..." >&2
    # Temporarily set BRANCH if not already set
    if [ -z "$BRANCH" ]; then
        BRANCH="main"
    fi
    # Download the i18n system
    if download_i18n_system; then
        source "$SCRIPT_DIR/i18n/i18n.sh"
        init_i18n "$OVERRIDE_LANG"
        echo "i18n system downloaded and loaded successfully." >&2
    else
        echo "Error: Could not download i18n system. Using fallback messages." >&2
        # Define basic fallback functions
        t() { echo "$1"; }
        init_i18n() { return 0; }
        MESSAGES_LOADED="fallback"
    fi
fi


#------------------------------------------------------------------------------
# DISPLAY COLORS
#------------------------------------------------------------------------------
COLOR_BLUE='\033[38;5;33m'    # Information
COLOR_GREEN='\033[38;5;82m'   # Success
COLOR_GOLD='\033[38;5;220m'   # Warning
COLOR_RED='\033[38;5;196m'    # Error
COLOR_RESET='\033[0m'         # Reset

#------------------------------------------------------------------------------
# REDIRECTION
#------------------------------------------------------------------------------
if [ "$VERBOSE" = false ]; then
    REDIRECT=">/dev/null 2>&1"
else
    REDIRECT=""
fi

#------------------------------------------------------------------------------
# DISPLAY HELP
#------------------------------------------------------------------------------
show_help() {
    clear
    echo "$(t "MSG_PROOT_HELP_TITLE")"
    echo 
    echo "$(t "MSG_PROOT_HELP_USAGE")"
    echo "$(t "MSG_PROOT_HELP_OPTIONS")"
    echo "  --gum | -g     $(t "MSG_PROOT_HELP_GUM")"
    echo "  --verbose | -v $(t "MSG_PROOT_HELP_VERBOSE")"
    echo "  --help | -h    $(t "MSG_PROOT_HELP_HELP")"
}

#------------------------------------------------------------------------------
# ARGUMENTS MANAGEMENT
#------------------------------------------------------------------------------
for ARG in "$@"; do
    case $ARG in
        --gum|-g)
            USE_GUM=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            REDIRECT=""
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --username=*)
            PROOT_USERNAME="${ARG#*=}"
            shift
            ;;
        --password=*)
            PROOT_PASSWORD="${ARG#*=}"
            shift
            ;;
        --lang|-l)
            # Skip --lang as it's already processed
            shift
            if [ -n "$1" ]; then
                shift
            fi
            ;;
        *)
            break
            ;;
    esac
done

#------------------------------------------------------------------------------
# INFORMATION MESSAGES
#------------------------------------------------------------------------------
info_msg() {
    if $USE_GUM; then
        gum style "${1//$'\n'/ }" --foreground 33
    else
        echo -e "${COLOR_BLUE}$1${COLOR_RESET}"
    fi
}

#------------------------------------------------------------------------------
# SUCCESS MESSAGES
#------------------------------------------------------------------------------
success_msg() {
    if $USE_GUM; then
        gum style "${1//$'\n'/ }" --foreground 82
    else
        echo -e "${COLOR_GREEN}$1${COLOR_RESET}"
    fi
}

#------------------------------------------------------------------------------
# ERROR MESSAGES
#------------------------------------------------------------------------------
error_msg() {
    if $USE_GUM; then
        gum style "${1//$'\n'/ }" --foreground 196
    else
        echo -e "${COLOR_RED}$1${COLOR_RESET}"
    fi
}

#------------------------------------------------------------------------------
# TITLE MESSAGES
#------------------------------------------------------------------------------
title_msg() {
    if $USE_GUM; then
        gum style "${1//$'\n'/ }" --foreground 220 --bold
    else
        echo -e "\n${COLOR_GOLD}\033[1m$1\033[0m${COLOR_RESET}"
    fi
}

#------------------------------------------------------------------------------
# SUBTITLE MESSAGES
#------------------------------------------------------------------------------
subtitle_msg() {
    if $USE_GUM; then
        gum style "${1//$'\n'/ }" --foreground 33 --bold
    else
        echo -e "\n${COLOR_BLUE}\033[1m$1\033[0m${COLOR_RESET}"
    fi
}

#------------------------------------------------------------------------------
# ERROR LOGGING
#------------------------------------------------------------------------------
log_error() {
    local ERROR_MSG="$1"
    local USERNAME=$(whoami)
    local HOSTNAME=$(hostname)
    local CWD=$(pwd)
    echo "[$(date +'%d/%m/%Y %H:%M:%S')] ERROR: $ERROR_MSG | User: $USERNAME | Machine: $HOSTNAME | Directory: $CWD" >> "$HOME/.config/OhMyTermux/install.log"
}

#------------------------------------------------------------------------------
# DYNAMIC DISPLAY OF COMMAND RESULTS
#------------------------------------------------------------------------------
execute_command() {
    local COMMAND="$1"
    local INFO_MSG="$2"
    local SUCCESS_MSG="✓ $INFO_MSG"
    local ERROR_MSG="✗ $INFO_MSG"
    local ERROR_DETAILS

    if $USE_GUM; then
        if gum spin --spinner.foreground="33" --title.foreground="33" --spinner dot --title "$INFO_MSG" -- bash -c "$COMMAND $REDIRECT"; then
            gum style "$SUCCESS_MSG" --foreground 82
        else
            ERROR_DETAILS="Command: $COMMAND, Redirect: $REDIRECT, Time: $(date +'%d/%m/%Y %H:%M:%S')"
            gum style "$ERROR_MSG" --foreground 196
            log_error "$ERROR_DETAILS"
            return 1
        fi
    else
        tput sc
        info_msg "$INFO_MSG"
        
        if eval "$COMMAND $REDIRECT"; then
            tput rc
            tput el
            success_msg "$SUCCESS_MSG"
        else
            tput rc
            tput el
            ERROR_DETAILS="Command: $COMMAND, Redirect: $REDIRECT, Time: $(date +'%d/%m/%Y %H:%M:%S')"
            error_msg "$ERROR_MSG"
            log_error "$ERROR_DETAILS"
            return 1
        fi
    fi
}

#------------------------------------------------------------------------------
# DEPENDENCIES CHECK
#------------------------------------------------------------------------------
check_dependencies() {
    if [ "$USE_GUM" = true ]; then
        if $USE_GUM && ! command -v gum &> /dev/null; then
            echo -e "${COLOR_BLUE}Installing gum${COLOR_RESET}"
            pkg update -y > /dev/null 2>&1 && pkg install gum -y > /dev/null 2>&1
        fi
    fi

    if ! command -v proot-distro &> /dev/null; then
        error_msg "Please install proot-distro before continuing."
        exit 1
    fi
}

#------------------------------------------------------------------------------
# TEXT BANNER
#------------------------------------------------------------------------------
bash_banner() {
    clear
    local BANNER="
╔════════════════════════════════════════╗
║                                        ║
║               OHMYTERMUX               ║
║                                        ║
╚════════════════════════════════════════╝"

    echo -e "${COLOR_BLUE}${BANNER}${COLOR_RESET}\n"
}


#------------------------------------------------------------------------------
# GRAPHIC BANNER
#------------------------------------------------------------------------------
show_banner() {
    clear
    if $USE_GUM; then
        gum style \
            --foreground 33 \
            --border-foreground 33 \
            --border double \
            --align center \
            --width 42 \
            --margin "1 1 1 0" \
            "" "OHMYTERMUX" ""
    else
        bash_banner
    fi
}

#------------------------------------------------------------------------------
# ERROR MANAGEMENT
#------------------------------------------------------------------------------
finish() {
    local RET=$?
    if [ ${RET} -ne 0 ] && [ ${RET} -ne 130 ]; then
        echo
        if [ "$USE_GUM" = true ]; then
            gum style --foreground 196 "$(t "MSG_PROOT_ERROR_INSTALL")"
        else
            echo -e "${COLOR_RED}$(t "MSG_PROOT_ERROR_INSTALL")${COLOR_RESET}"
        fi
        echo -e "${COLOR_BLUE}$(t "MSG_PROOT_ERROR_REFER")${COLOR_RESET}"
    fi
}

trap finish EXIT

#------------------------------------------------------------------------------
# PROOT PACKAGES INSTALLATION
#------------------------------------------------------------------------------
install_packages_proot() {
    local PKGS_PROOT=('sudo' 'wget' 'nala' 'xfconf')
    #local PKGS_PROOT=('sudo' 'wget' 'nala' 'xfconf' 'gnome-themes-extra')
    for PKG in "${PKGS_PROOT[@]}"; do
        execute_command "proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 apt install $PKG -y" "Installation of $PKG"
    done
}

#------------------------------------------------------------------------------
# PROOT USER CREATION
#------------------------------------------------------------------------------
create_user_proot() {
    execute_command "
        proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 groupadd storage
        proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 groupadd wheel
        proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 useradd -m -g users -G wheel,audio,video,storage -s /bin/bash '$USERNAME'
        echo '$USERNAME:$PASSWORD' | proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 chpasswd
    " "User creation"
}

#------------------------------------------------------------------------------
# USER RIGHTS CONFIGURATION
#------------------------------------------------------------------------------
configure_user_rights() {
    execute_command "
        # Add user to sudo group
        proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 usermod -aG sudo '$USERNAME'

        # Create sudoers.d file for user
        echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' > '$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers.d/$USERNAME'
        chmod 0440 '$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers.d/$USERNAME'

        # Main sudoers file configuration
        echo '%sudo ALL=(ALL:ALL) ALL' >> '$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers'

        # Check permissions
        chmod 440 '$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers'
        chown root:root '$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers'
    " "Sudo rights configuration"
}

#------------------------------------------------------------------------------
# MESA-VULKAN INSTALLATION
#------------------------------------------------------------------------------
install_mesa_vulkan() {
    local MESA_PACKAGE="mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
    local MESA_URL="https://github.com/GiGiDKR/OhMyTermux/raw/$BRANCH/src/$MESA_PACKAGE"

    if ! proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 dpkg -s mesa-vulkan-kgsl &> /dev/null; then
        execute_command "proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 wget $MESA_URL" "$(t "MSG_PROOT_MESA_DOWNLOAD")"
        execute_command "proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 sudo apt install -y ./$MESA_PACKAGE" "$(t "MSG_PROOT_MESA_INSTALLATION")"
    else
        info_msg "$(t "MSG_PROOT_MESA_ALREADY_INSTALLED")"
    fi
}

#------------------------------------------------------------------------------
# THEMES COPY
#------------------------------------------------------------------------------
copy_theme() {
    local theme_name="$1"
    local theme_path=""
    
    case $theme_name in
        "WhiteSur")
            theme_path="WhiteSur-Dark"
            ;;
        "Fluent")
            theme_path="Fluent-dark-compact"
            ;;
        "Lavanda")
            theme_path="Lavanda-dark-compact"
            ;;
    esac

    execute_command "cp -r $PREFIX/share/themes/$theme_path $PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/themes/" "$(t "MSG_PROOT_THEME_CONFIGURATION")"
}

#------------------------------------------------------------------------------
# ICONS COPY
#------------------------------------------------------------------------------
copy_icons() {
    local icon_theme="$1"
    local icon_path=""
    
    case $icon_theme in
        "WhiteSur")
            icon_path="WhiteSur-dark"
            ;;
        "McMojave-circle")
            icon_path="McMojave-circle-dark"
            ;;
        "Tela")
            icon_path="Tela-dark"
            ;;
        "Fluent")
            icon_path="Fluent-dark"
            ;;
        "Qogir")
            icon_path="Qogir-dark"
            ;;
    esac
    
    execute_command "cp -r $PREFIX/share/icons/$icon_path $PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/icons/" "$(t "MSG_PROOT_ICONS_CONFIGURATION")"
}

#------------------------------------------------------------------------------
# THEMES AND ICONS CONFIGURATION
#------------------------------------------------------------------------------
configure_themes_and_icons() {
    # Load configuration from temporary file
    if [ -f "$HOME/.config/OhMyTermux/theme_config.tmp" ]; then
        source "$HOME/.config/OhMyTermux/theme_config.tmp"
    fi

    # Create necessary directories
    execute_command "
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/themes\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/icons\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/backgrounds/whitesur\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$USERNAME/.fonts/\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$USERNAME/.themes/\"
    " "$(t "MSG_PROOT_CREATING_DIRECTORIES")"

    # Copy themes if installed
    if [ "$INSTALL_THEME" = true ] && [ -n "$SELECTED_THEME" ]; then
        copy_theme "$SELECTED_THEME"
    fi

    # Copy icons if installed
    if [ "$INSTALL_ICONS" = true ] && [ -n "$SELECTED_ICON_THEME" ]; then
        copy_icons "$SELECTED_ICON_THEME"
    fi

    # Copy wallpapers if installed
    if [ "$INSTALL_WALLPAPERS" = true ]; then
        execute_command "cp -r $PREFIX/share/backgrounds/whitesur/* $PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/backgrounds/whitesur/" "$(t "MSG_PROOT_WALLPAPERS_CONFIG")"
    fi

    # Cursors configuration
    if [ "$INSTALL_CURSORS" = true ]; then
        cd "$PREFIX/share/icons"
        execute_command "find dist-dark | cpio -pdm \"$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/icons\"" "$(t "MSG_PROOT_CURSORS_CONFIG")"

        # Xresources configuration
        cat << EOF > "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$USERNAME/.Xresources"
Xcursor.theme: dist-dark
EOF
    fi

    # Delete the temporary configuration file
    rm -f "$HOME/.config/OhMyTermux/theme_config.tmp"
}

#------------------------------------------------------------------------------
# MAIN FUNCTION
#------------------------------------------------------------------------------
check_dependencies
title_msg "$(t "MSG_PROOT_DEBIAN_INSTALLATION")"

if [ $# -eq 0 ] && [ -z "$PROOT_USERNAME" ] && [ -z "$PROOT_PASSWORD" ]; then
    if [ "$USE_GUM" = true ]; then
        PROOT_USERNAME=$(gum input --prompt "$(t "MSG_PROOT_USERNAME_PROMPT")" --placeholder "$(t "MSG_PROOT_USERNAME_PLACEHOLDER")")
        while true; do
            PROOT_PASSWORD=$(gum input --password --prompt "$(t "MSG_PROOT_PASSWORD_PROMPT")" --placeholder "$(t "MSG_PROOT_PASSWORD_PLACEHOLDER")")
            PASSWORD_CONFIRM=$(gum input --password --prompt "$(t "MSG_PROOT_CONFIRM_PROMPT")" --placeholder "$(t "MSG_PROOT_CONFIRM_PLACEHOLDER")")
            if [ "$PROOT_PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                gum style --foreground 196 "$(t "MSG_PROOT_PASSWORDS_NO_MATCH")"
            fi
        done
    else
        echo -e "${COLOR_BLUE}$(t "MSG_PROOT_ENTER_USERNAME")${COLOR_RESET}"
        read -r PROOT_USERNAME
        tput cuu1
        tput el
        while true; do
            echo -e "${COLOR_BLUE}$(t "MSG_PROOT_ENTER_PASSWORD")${COLOR_RESET}"
            read -rs PROOT_PASSWORD
            tput cuu1
            tput el
            echo -e "${COLOR_BLUE}$(t "MSG_PROOT_CONFIRM_PASSWORD")${COLOR_RESET}"
            read -rs PASSWORD_CONFIRM
            tput cuu1
            tput el 
            if [ "$PROOT_PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                echo -e "${COLOR_RED}$(t "MSG_PROOT_PASSWORDS_NO_MATCH")${COLOR_RESET}"
                tput cuu1
                tput el
            fi
        done
    fi
elif [ $# -eq 1 ] && [ -z "$PROOT_PASSWORD" ]; then
    PROOT_USERNAME="$1"
    if [ "$USE_GUM" = true ]; then
        while true; do
            PROOT_PASSWORD=$(gum input --password --prompt "$(t "MSG_PROOT_PASSWORD_PROMPT")" --placeholder "$(t "MSG_PROOT_PASSWORD_PLACEHOLDER")")
            PASSWORD_CONFIRM=$(gum input --password --prompt "$(t "MSG_PROOT_CONFIRM_PROMPT")" --placeholder "$(t "MSG_PROOT_CONFIRM_PLACEHOLDER")")
            if [ "$PROOT_PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                gum style --foreground 196 "$(t "MSG_PROOT_PASSWORDS_NO_MATCH")"
            fi
        done
    else
        while true; do
            echo -e "${COLOR_BLUE}$(t "MSG_PROOT_ENTER_PASSWORD")${COLOR_RESET}"
            read -rs PROOT_PASSWORD
            tput cuu1
            tput el
            echo -e "${COLOR_BLUE}$(t "MSG_PROOT_CONFIRM_PASSWORD")${COLOR_RESET}"
            read -rs PASSWORD_CONFIRM
            tput cuu1
            tput el
            if [ "$PROOT_PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                echo -e "${COLOR_RED}$(t "MSG_PROOT_PASSWORDS_NO_MATCH")${COLOR_RESET}"
                tput cuu1
                tput el
            fi
        done
    fi
elif [ $# -eq 2 ] && [ -z "$PROOT_USERNAME" ] && [ -z "$PROOT_PASSWORD" ]; then
    PROOT_USERNAME="$1"
    PROOT_PASSWORD="$2"
fi

execute_command "proot-distro install debian" "$(t "MSG_PROOT_DISTRIBUTION_INSTALLATION")"

#------------------------------------------------------------------------------
# DEBIAN INSTALLATION CHECK
#------------------------------------------------------------------------------
if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
    error_msg "$(t "MSG_PROOT_DEBIAN_FAILED")"
    exit 1
fi

execute_command "proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 apt update" "$(t "MSG_PROOT_UPDATE_SEARCH")"
execute_command "proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 apt upgrade -y" "$(t "MSG_PROOT_UPDATE_PACKAGES")"

install_packages_proot

subtitle_msg "$(t "MSG_PROOT_DISTRIBUTION_CONFIG")"

# Use PROOT_USERNAME and PROOT_PASSWORD for create_user_proot
USERNAME="$PROOT_USERNAME"
PASSWORD="$PROOT_PASSWORD"
create_user_proot
configure_user_rights

#------------------------------------------------------------------------------
# TIMEZONE CONFIGURATION
#------------------------------------------------------------------------------
TIMEZONE=$(getprop persist.sys.timezone)
execute_command "
    proot-distro login debian -- rm /etc/localtime
    proot-distro login debian -- cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime
" "$(t "MSG_PROOT_TIMEZONE_CONFIG_MSG")"

#------------------------------------------------------------------------------
# GRAPHIC CONFIGURATION
#------------------------------------------------------------------------------
configure_themes_and_icons

#------------------------------------------------------------------------------
# MESA-VULKAN INSTALLATION
#------------------------------------------------------------------------------
install_mesa_vulkan