#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GitHub branch for downloads
BRANCH="1.1.02"

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
SELECTED_DISTRO="debian"

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

#------------------------------------------------------------------------------
# BOOTSTRAP - Load i18n and lib systems
#------------------------------------------------------------------------------
_bootstrap_url="https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/lib/bootstrap.sh"
_validate_script() { head -1 "$1" 2>/dev/null | grep -q "^#!/bin/bash"; }

mkdir -p "$SCRIPT_DIR/lib"
if [ ! -f "$SCRIPT_DIR/lib/bootstrap.sh" ] || ! _validate_script "$SCRIPT_DIR/lib/bootstrap.sh"; then
    curl -fL -s -o "$SCRIPT_DIR/lib/bootstrap.sh" "$_bootstrap_url" 2>/dev/null
    if ! _validate_script "$SCRIPT_DIR/lib/bootstrap.sh"; then
        echo "Error: Failed to download bootstrap.sh from $_bootstrap_url" >&2
        exit 1
    fi
fi
source "$SCRIPT_DIR/lib/bootstrap.sh"

# Download and load i18n
if [ ! -f "$SCRIPT_DIR/i18n/i18n.sh" ] || ! _validate_script "$SCRIPT_DIR/i18n/i18n.sh"; then
    echo "Initializing i18n system..." >&2
    if download_i18n_system && _validate_script "$SCRIPT_DIR/i18n/i18n.sh"; then
        echo "i18n system downloaded and loaded successfully." >&2
    else
        echo "Error: Could not download i18n system. Using fallback messages." >&2
        t() { echo "$1"; }
        init_i18n() { return 0; }
        MESSAGES_LOADED="fallback"
    fi
fi
[ -f "$SCRIPT_DIR/i18n/i18n.sh" ] && _validate_script "$SCRIPT_DIR/i18n/i18n.sh" && source "$SCRIPT_DIR/i18n/i18n.sh"
type init_i18n &>/dev/null && init_i18n "$OVERRIDE_LANG"

# Download and load lib
if [ ! -f "$SCRIPT_DIR/lib/common.sh" ] || ! _validate_script "$SCRIPT_DIR/lib/common.sh"; then
    download_lib_system
fi
source "$SCRIPT_DIR/lib/common.sh"

# Configure error handler keys for this script
ERROR_MSG_KEY="MSG_PROOT_ERROR_INSTALL"
ERROR_REFER_KEY="MSG_PROOT_ERROR_REFER"

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
        --distro=*)
            SELECTED_DISTRO="${ARG#*=}"
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

trap finish EXIT

#------------------------------------------------------------------------------
# PROOT PACKAGES INSTALLATION
#------------------------------------------------------------------------------
install_packages_proot() {
    case $SELECTED_DISTRO in
        debian|ubuntu)
            local PKGS_PROOT=('sudo' 'wget' 'nala' 'xfconf')
            for PKG in "${PKGS_PROOT[@]}"; do
                execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 apt install $PKG -y" "Installation of $PKG"
            done
            ;;
        archlinux)
            execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- pacman -Syu --noconfirm sudo wget xfconf" "Installation of packages"
            ;;
        fedora)
            execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- dnf install -y sudo wget xfconf" "Installation of packages"
            ;;
        alpine)
            execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- apk add sudo wget xfconf" "Installation of packages"
            ;;
        void)
            execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- xbps-install -Sy sudo wget xfconf" "Installation of packages"
            ;;
        opensuse)
            execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- zypper install -y sudo wget xfconf" "Installation of packages"
            ;;
    esac
}

#------------------------------------------------------------------------------
# PROOT USER CREATION
#------------------------------------------------------------------------------
create_user_proot() {
    case $SELECTED_DISTRO in
        alpine)
            execute_command "
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 addgroup storage 2>/dev/null || true
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 addgroup wheel 2>/dev/null || true
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 adduser -D -G users -s /bin/ash '$USERNAME'
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 addgroup '$USERNAME' wheel
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 addgroup '$USERNAME' audio
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 addgroup '$USERNAME' video
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 addgroup '$USERNAME' storage
                echo '$USERNAME:$PASSWORD' | proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 chpasswd
            " "User creation"
            ;;
        *)
            execute_command "
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 groupadd storage 2>/dev/null || true
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 groupadd wheel 2>/dev/null || true
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 useradd -m -g users -G wheel,audio,video,storage -s /bin/bash '$USERNAME'
                echo '$USERNAME:$PASSWORD' | proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 chpasswd
            " "User creation"
            ;;
    esac
}

#------------------------------------------------------------------------------
# USER RIGHTS CONFIGURATION
#------------------------------------------------------------------------------
configure_user_rights() {
    local ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO"

    case $SELECTED_DISTRO in
        debian|ubuntu)
            execute_command "
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 usermod -aG sudo '$USERNAME'
                echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' > '$ROOTFS/etc/sudoers.d/$USERNAME'
                chmod 0440 '$ROOTFS/etc/sudoers.d/$USERNAME'
                echo '%sudo ALL=(ALL:ALL) ALL' >> '$ROOTFS/etc/sudoers'
                chmod 440 '$ROOTFS/etc/sudoers'
                chown root:root '$ROOTFS/etc/sudoers'
            " "Sudo rights configuration"
            ;;
        alpine)
            execute_command "
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 addgroup '$USERNAME' wheel
                mkdir -p '$ROOTFS/etc/sudoers.d'
                echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' > '$ROOTFS/etc/sudoers.d/$USERNAME'
                chmod 0440 '$ROOTFS/etc/sudoers.d/$USERNAME'
                echo '%wheel ALL=(ALL:ALL) ALL' >> '$ROOTFS/etc/sudoers'
                chmod 440 '$ROOTFS/etc/sudoers'
                chown root:root '$ROOTFS/etc/sudoers'
            " "Sudo rights configuration"
            ;;
        *)
            execute_command "
                proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 usermod -aG wheel '$USERNAME'
                mkdir -p '$ROOTFS/etc/sudoers.d'
                echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' > '$ROOTFS/etc/sudoers.d/$USERNAME'
                chmod 0440 '$ROOTFS/etc/sudoers.d/$USERNAME'
                echo '%wheel ALL=(ALL:ALL) ALL' >> '$ROOTFS/etc/sudoers'
                chmod 440 '$ROOTFS/etc/sudoers'
                chown root:root '$ROOTFS/etc/sudoers'
            " "Sudo rights configuration"
            ;;
    esac
}

#------------------------------------------------------------------------------
# MESA-VULKAN INSTALLATION
#------------------------------------------------------------------------------
install_mesa_vulkan() {
    case $SELECTED_DISTRO in
        debian|ubuntu)
            local MESA_PACKAGE="mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
            local MESA_URL="https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/src/$MESA_PACKAGE"

            if ! proot-distro login $SELECTED_DISTRO --shared-tmp -- dpkg -s mesa-vulkan-kgsl &> /dev/null; then
                execute_command "curl -fL -o $PREFIX/tmp/$MESA_PACKAGE $MESA_URL" "$(t "MSG_PROOT_MESA_DOWNLOAD")"
                execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- apt install -y /tmp/$MESA_PACKAGE" "$(t "MSG_PROOT_MESA_INSTALLATION")"
            else
                info_msg "$(t "MSG_PROOT_MESA_ALREADY_INSTALLED")"
            fi
            ;;
        *)
            info_msg "$(t "MSG_PROOT_MESA_SKIP")"
            ;;
    esac
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

    execute_command "cp -r $PREFIX/share/themes/$theme_path $PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/usr/share/themes/" "$(t "MSG_PROOT_THEME_CONFIGURATION")"
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

    execute_command "cp -r $PREFIX/share/icons/$icon_path $PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/usr/share/icons/" "$(t "MSG_PROOT_ICONS_CONFIGURATION")"
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
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/usr/share/themes\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/usr/share/icons\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/usr/share/backgrounds/whitesur\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/home/$USERNAME/.fonts/\"
        mkdir -p \"$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/home/$USERNAME/.themes/\"
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
        execute_command "cp -r $PREFIX/share/backgrounds/whitesur/* $PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/usr/share/backgrounds/whitesur/" "$(t "MSG_PROOT_WALLPAPERS_CONFIG")"
    fi

    # Cursors configuration
    if [ "$INSTALL_CURSORS" = true ]; then
        cd "$PREFIX/share/icons"
        execute_command "find dist-dark | cpio -pdm \"$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/usr/share/icons\"" "$(t "MSG_PROOT_CURSORS_CONFIG")"

        # Xresources configuration
        cat << EOF > "$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO/home/$USERNAME/.Xresources"
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
title_msg "$(printf "$(t "MSG_PROOT_DISTRO_INSTALLATION")" "$SELECTED_DISTRO")"

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

execute_command "proot-distro install $SELECTED_DISTRO" "$(t "MSG_PROOT_DISTRIBUTION_INSTALLATION")"

#------------------------------------------------------------------------------
# DEBIAN INSTALLATION CHECK
#------------------------------------------------------------------------------
if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/$SELECTED_DISTRO" ]; then
    error_msg "$(printf "$(t "MSG_PROOT_DISTRO_FAILED")" "$SELECTED_DISTRO")"
    exit 1
fi

case $SELECTED_DISTRO in
    debian|ubuntu)
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 apt update" "$(t "MSG_PROOT_UPDATE_SEARCH")"
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- env DISPLAY=:1.0 apt upgrade -y" "$(t "MSG_PROOT_UPDATE_PACKAGES")"
        ;;
    archlinux)
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- pacman -Syu --noconfirm" "$(t "MSG_PROOT_UPDATE_PACKAGES")"
        ;;
    fedora)
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- dnf update -y" "$(t "MSG_PROOT_UPDATE_PACKAGES")"
        ;;
    alpine)
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- apk update" "$(t "MSG_PROOT_UPDATE_SEARCH")"
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- apk upgrade" "$(t "MSG_PROOT_UPDATE_PACKAGES")"
        ;;
    void)
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- xbps-install -Syu" "$(t "MSG_PROOT_UPDATE_PACKAGES")"
        ;;
    opensuse)
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- zypper refresh" "$(t "MSG_PROOT_UPDATE_SEARCH")"
        execute_command "proot-distro login $SELECTED_DISTRO --shared-tmp -- zypper update -y" "$(t "MSG_PROOT_UPDATE_PACKAGES")"
        ;;
esac

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
    proot-distro login $SELECTED_DISTRO -- rm /etc/localtime
    proot-distro login $SELECTED_DISTRO -- cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime
" "$(t "MSG_PROOT_TIMEZONE_CONFIG_MSG")"

#------------------------------------------------------------------------------
# GRAPHIC CONFIGURATION
#------------------------------------------------------------------------------
configure_themes_and_icons

#------------------------------------------------------------------------------
# MESA-VULKAN INSTALLATION
#------------------------------------------------------------------------------
install_mesa_vulkan
