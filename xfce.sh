#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GitHub branch for downloads
BRANCH="main"

# Language override variable
OVERRIDE_LANG=""

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

# Function to download the i18n system if needed
download_i18n_system() {
    local BASE_URL="https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH"
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

        # Create directory if needed
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
# GLOBAL VARIABLES
#------------------------------------------------------------------------------
USE_GUM=false
VERBOSE=false
BROWSER="chromium"

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
    echo "$(t "MSG_XFCE_HELP_TITLE")"
    echo 
    echo "$(t "MSG_XFCE_HELP_USAGE")"
    echo "$(t "MSG_XFCE_HELP_OPTIONS")"
    echo "  --gum | -g        $(t "MSG_XFCE_HELP_GUM")"
    echo "  --verbose | -v    $(t "MSG_XFCE_HELP_VERBOSE")"
    echo "  --browser | -b    $(t "MSG_XFCE_HELP_BROWSER")"
    echo "  --version | -ver  $(t "MSG_XFCE_HELP_VERSION")"
    echo "  --full            $(t "MSG_XFCE_HELP_FULL")"
    echo "  --help | -h       $(t "MSG_XFCE_HELP_HELP")"
}

#------------------------------------------------------------------------------
# CUSTOM VARIABLES
#------------------------------------------------------------------------------
INSTALL_THEME=false
INSTALL_ICONS=false
INSTALL_WALLPAPERS=false
INSTALL_CURSORS=false
INSTALL_TYPE=""
SELECTED_THEME="WhiteSur"
SELECTED_THEMES=()
SELECTED_ICON_THEME="WhiteSur"
SELECTED_ICON_THEMES=()
SELECTED_WALLPAPER="Monterey.jpg"

#------------------------------------------------------------------------------
# COMPLETE VARIABLES
#------------------------------------------------------------------------------
FULL_INSTALL=false
XFCE_VERSION=""
BROWSER_CHOICE=""
INSTALL_THEME=false
INSTALL_ICONS=false
INSTALL_WALLPAPERS=false
INSTALL_CURSORS=false
SELECTED_THEME=""
SELECTED_ICON_THEME=""
SELECTED_WALLPAPER=""

#------------------------------------------------------------------------------
# ARGUMENTS MANAGEMENT
#------------------------------------------------------------------------------
for arg in "$@"; do
    case $arg in
        --gum|-g)
            USE_GUM=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            REDIRECT=""
            shift
            ;;
        --browser|-b)
            BROWSER="${2}"
            shift 2
            ;;
        --version=*)
            INSTALL_TYPE="${arg#*=}"
            shift
            ;;
        --full)
            FULL_INSTALL=true
            XFCE_VERSION="recommended"
            BROWSER_CHOICE="chromium"
            INSTALL_THEME=true
            INSTALL_ICONS=true
            INSTALL_WALLPAPERS=true
            INSTALL_CURSORS=true
            SELECTED_THEMES=("WhiteSur")
            SELECTED_THEME="WhiteSur-Dark"
            SELECTED_ICON_THEME="WhiteSur"
            SELECTED_WALLPAPER="WhiteSur"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
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
# GUM CONFIRMATION
#------------------------------------------------------------------------------
gum_confirm() {
    local PROMPT="$1"
    if $FULL_INSTALL; then
        return 0 
    else
        gum confirm --affirmative "$(t CONFIRM_YES)" --negative "$(t CONFIRM_NO)" --prompt.foreground="33" --selected.background="33" --selected.foreground="0" "$PROMPT"
    fi
}

#------------------------------------------------------------------------------
# GUM UNIQUE SELECTION
#------------------------------------------------------------------------------
gum_choose() {
    local PROMPT="$1"
    shift
    local SELECTED=""
    local OPTIONS=()
    local HEIGHT=10

    while [[ $# -gt 0 ]]; do
        case $1 in
            --selected=*)
                SELECTED="${1#*=}"
                ;;
            --height=*)
                HEIGHT="${1#*=}"
                ;;
            *)
                OPTIONS+=("$1")
                ;;
        esac
        shift
    done

    gum choose --selected.foreground="33" --header.foreground="33" --cursor.foreground="33" --height="$HEIGHT" --header="$PROMPT" --selected="$SELECTED" "${OPTIONS[@]}"
}

#------------------------------------------------------------------------------
# GUM MULTIPLE SELECTION
#------------------------------------------------------------------------------
gum_choose_multi() {
    local PROMPT="$1"
    shift
    local SELECTED=""
    local OPTIONS=()
    local HEIGHT=10

    while [[ $# -gt 0 ]]; do
        case $1 in
            --selected=*)
                SELECTED="${1#*=}"
                ;;
            --height=*)
                HEIGHT="${1#*=}"
                ;;
            *)
                OPTIONS+=("$1")
                ;;
        esac
        shift
    done

    gum choose --no-limit --selected.foreground="33" --header.foreground="33" --cursor.foreground="33" --height="$HEIGHT" --header="$PROMPT" --selected="$SELECTED" "${OPTIONS[@]}"
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
        if $USE_GUM; then
            gum style --foreground 196 "$(t "MSG_XFCE_ERROR_INSTALL")"
        else
            echo -e "${COLOR_RED}$(t "MSG_XFCE_ERROR_INSTALL")${COLOR_RESET}"
        fi
        echo -e "${COLOR_BLUE}$(t "MSG_XFCE_ERROR_REFER")${COLOR_RESET}"
    fi
}

#------------------------------------------------------------------------------
# INFO MESSAGES
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
    echo "[$(date +'%d/%m/%Y %H:%M:%S')] ERROR: $ERROR_MSG | User: $USERNAME | Host: $HOSTNAME | Directory: $CWD" >> "$HOME/.config/OhMyTermux/install.log"
}

#------------------------------------------------------------------------------
# DYNAMIC RESULT DISPLAY
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
# FILE DOWNLOAD
#------------------------------------------------------------------------------
download_file() {
    local URL=$1
    local MESSAGE=$2
    execute_command "wget $URL" "$MESSAGE"
}

trap finish EXIT

#------------------------------------------------------------------------------
# XFCE CONFIGURATION
#------------------------------------------------------------------------------
configure_xfce() {
    local CONFIG_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    local INSTALL_TYPE="$1"
    local BROWSER_DESKTOP

    # Set the browser .desktop file
    if [ "$BROWSER" = "firefox" ]; then
        BROWSER_DESKTOP="firefox"
    elif [ "$BROWSER" = "chromium" ]; then
        BROWSER_DESKTOP="chromium"
    else
        BROWSER_DESKTOP="$BROWSER"
    fi

    # Create the configuration directory if it doesn't exist
    mkdir -p "$CONFIG_DIR" >/dev/null 2>&1

    # Configure the default browser
    cat > "$CONFIG_DIR/xfce4-mime-settings.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-mime-settings" version="1.0">
  <property name="last" type="empty">
    <property name="window-width" type="int" value="550"/>
    <property name="window-height" type="int" value="400"/>
    <property name="mime-width" type="int" value="300"/>
    <property name="status-width" type="int" value="75"/>
    <property name="default-width" type="int" value="150"/>
  </property>
  <property name="default" type="empty">
    <property name="x-scheme-handler/http" type="string" value="$BROWSER_DESKTOP.desktop"/>
    <property name="x-scheme-handler/https" type="string" value="$BROWSER_DESKTOP.desktop"/>
  </property>
</channel>
EOF

    # Create the mimeapps.list file
    mkdir -p "$HOME/.config" >/dev/null 2>&1
    cat > "$HOME/.config/mimeapps.list" << EOF
[Default Applications]
x-scheme-handler/http=$BROWSER_DESKTOP.desktop
x-scheme-handler/https=$BROWSER_DESKTOP.desktop
text/html=$BROWSER_DESKTOP.desktop
application/xhtml+xml=$BROWSER_DESKTOP.desktop

[Added Associations]
x-scheme-handler/http=$BROWSER_DESKTOP.desktop
x-scheme-handler/https=$BROWSER_DESKTOP.desktop
text/html=$BROWSER_DESKTOP.desktop
application/xhtml+xml=$BROWSER_DESKTOP.desktop
EOF

    # Configure xfce4-terminal
    mkdir -p "$HOME/.config/xfce4/terminal" >/dev/null 2>&1
    cat > "$HOME/.config/xfce4/terminal/terminalrc" << EOF
[Configuration]
FontName=Monospace 11
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBellUrgent=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=120x30
MiscInheritGeometry=FALSE
MiscMenubarDefault=FALSE
MiscMouseAutohide=FALSE
MiscMouseWheelZoom=TRUE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabCloseMiddleClick=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
MiscMiddleClickOpensUri=FALSE
MiscRightClickAction=TERMINAL_RIGHT_CLICK_ACTION_CONTEXT_MENU
MiscCopyOnSelect=FALSE
MiscShowRelaunchDialog=TRUE
MiscRewrapOnResize=TRUE
MiscUseShiftArrowsToScroll=FALSE
MiscSlimTabs=FALSE
MiscNewTabAdjacent=FALSE
ScrollingBar=TERMINAL_SCROLLBAR_NONE
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.800000
TitleMode=TERMINAL_TITLE_HIDE
ScrollingLines=10000
ColorForeground=#c0caf5
ColorBackground=#1a1b26
ColorCursor=#c0caf5
ColorPalette=#15161e;#f7768e;#9ece6a;#e0af68;#7aa2f7;#bb9af7;#7dcfff;#a9b1d6;#414868;#f7768e;#9ece6a;#e0af68;#7aa2f7;#bb9af7;#7dcfff;#c0caf5
EOF

    # Configure xfce4-panel.xml if whiskermenu is not installed
    if ! command -v xfce4-popup-whiskermenu &> /dev/null; then
        sed -i 's/<property name="plugin-5" type="string" value="whiskermenu">/<property name="plugin-5" type="string" value="applicationsmenu">/' "$CONFIG_DIR/xfce4-panel.xml" >/dev/null 2>&1
        sed -i '/<property name="plugin-5".*whiskermenu/,/<\/property>/c\    <property name="plugin-5" type="string" value="applicationsmenu"/>' "$CONFIG_DIR/xfce4-panel.xml" >/dev/null 2>&1
    fi

    case "$INSTALL_TYPE" in
        "recommended")
            # Complete configuration with all elements
            cat > "$CONFIG_DIR/xsettings.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="WhiteSur-Dark"/>
    <property name="IconThemeName" type="string" value="WhiteSur-dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeName" type="string" value="dist-dark"/>
    <property name="CursorThemeSize" type="int" value="32"/>
  </property>
</channel>
EOF

            cat > "$CONFIG_DIR/xfwm4.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="WhiteSur-Dark"/>
  </property>
</channel>
EOF
            ;;

        "minimal"|"customized")
            # Base configuration
            local THEME_VALUE="Default"
            local ICON_VALUE="Adwaita"
            local CURSOR_VALUE="default"
            local WALLPAPER="/data/data/com.termux/files/usr/share/backgrounds/xfce/xfce-stripes.png"

            # Adjust according to custom choices
            if [ "$INSTALL_THEME" = true ]; then
                case $SELECTED_THEME in
                    "WhiteSur") THEME_VALUE="WhiteSur-Dark" ;;
                    "Fluent") THEME_VALUE="Fluent-dark-compact" ;;
                    "Lavanda") THEME_VALUE="Lavanda-dark-compact" ;;
                esac
            fi

            if [ "$INSTALL_ICONS" = true ]; then
                case $SELECTED_ICON_THEME in
                    "WhiteSur") ICON_VALUE="WhiteSur-dark" ;;
                    "McMojave-circle") ICON_VALUE="McMojave-circle-dark" ;;
                    "Tela") ICON_VALUE="Tela-dark" ;;
                    "Fluent") ICON_VALUE="Fluent-dark" ;;
                    "Qogir") ICON_VALUE="Qogir-dark" ;;
                esac
            fi

            [ "$INSTALL_CURSORS" = true ] && CURSOR_VALUE="dist-dark"
            [ "$INSTALL_WALLPAPERS" = true ] && WALLPAPER="/data/data/com.termux/files/usr/share/backgrounds/whitesur/${SELECTED_WALLPAPER}.jpg"

            # Generate xsettings.xml
            cat > "$CONFIG_DIR/xsettings.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="$THEME_VALUE"/>
    <property name="IconThemeName" type="string" value="$ICON_VALUE"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeName" type="string" value="$CURSOR_VALUE"/>
    <property name="CursorThemeSize" type="int" value="32"/>
  </property>
</channel>
EOF

            # Generate xfwm4.xml
            cat > "$CONFIG_DIR/xfwm4.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="$THEME_VALUE"/>
  </property>
</channel>
EOF

            # Generate xfce4-desktop.xml
            cat > "$CONFIG_DIR/xfce4-desktop.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorBuiltinDisplay" type="empty">
        <property name="workspace0" type="empty">
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="$WALLPAPER"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="file-icons" type="empty">
      <property name="show-home" type="bool" value="false"/>
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF
            ;;
    esac

    # Apply permissions
    chmod 644 "$CONFIG_DIR"/*.xml >/dev/null 2>&1
}

#------------------------------------------------------------------------------
# THEME CONFIGURATION SAVE
#------------------------------------------------------------------------------
save_theme_config() {
    mkdir -p "$HOME/.config/OhMyTermux"
    cat > "$HOME/.config/OhMyTermux/theme_config.tmp" << EOF
INSTALL_THEME=$INSTALL_THEME
INSTALL_ICONS=$INSTALL_ICONS
INSTALL_WALLPAPERS=$INSTALL_WALLPAPERS
INSTALL_CURSORS=$INSTALL_CURSORS
SELECTED_THEME="$SELECTED_THEME"
SELECTED_ICON_THEME="$SELECTED_ICON_THEME"
SELECTED_WALLPAPER="$SELECTED_WALLPAPER"
EOF
}

#------------------------------------------------------------------------------
# THEME INSTALLATION
#------------------------------------------------------------------------------
install_theme_pack() {
    local THEME_NAME="$1"
    local DOWNLOAD_URL="$2"
    local INSTALL_MESSAGE="$3"
    local ARCHIVE="theme.zip"

    # Download the archive
    execute_command "wget -O $ARCHIVE '$DOWNLOAD_URL'" "Download theme $THEME_NAME"

    # Extract the archive
    execute_command "unzip -o $ARCHIVE" "Extraction of theme $THEME_NAME"

    # Detect the name of the extracted directory
    local EXTRACTED_DIR=$(ls -d */ | grep -i "$THEME_NAME" | head -n 1)

    # Install theme
    case $THEME_NAME in
        "WhiteSur")
            execute_command "cd '$EXTRACTED_DIR' && \
                            tar -xf release/WhiteSur-Dark.tar.xz && \
                            mv WhiteSur-Dark/ $PREFIX/share/themes/ && \
                            cd .. && \
                            rm -rf '$EXTRACTED_DIR' $ARCHIVE" "$INSTALL_MESSAGE"
            ;;
        *)
            execute_command "cd '$EXTRACTED_DIR' && \
                            ./install.sh -d $PREFIX/share/themes -c dark -s compact && \
                            cd .. && \
                            rm -rf '$EXTRACTED_DIR' $ARCHIVE" "$INSTALL_MESSAGE"
            ;;
    esac
}

install_themes() {
    if $INSTALL_THEME; then
        # If it's a complete installation, set WhiteSur as the default theme
        if $FULL_INSTALL; then
            SELECTED_THEMES=("WhiteSur")
            SELECTED_THEME="WhiteSur"
        fi

        # Installation of selected themes
        for THEME in "${SELECTED_THEMES[@]}"; do
            case $THEME in
                "WhiteSur")
                    install_theme_pack "WhiteSur" "https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/refs/tags/2024-11-18.zip" "Install theme WhiteSur"
                    ;;
                "Fluent")
                    install_theme_pack "Fluent" "https://github.com/vinceliuice/Fluent-gtk-theme/archive/refs/heads/master.zip" "Install theme Fluent"
                    ;;
                "Lavanda")
                    install_theme_pack "Lavanda" "https://github.com/vinceliuice/Lavanda-gtk-theme/archive/refs/heads/main.zip" "Install theme Lavanda"
                    ;;
            esac
        done
    fi
}

#------------------------------------------------------------------------------
# ICON INSTALLATION
#------------------------------------------------------------------------------
install_icon_pack() {
    local ICON_NAME="$1"
    local DOWNLOAD_URL="$2"
    local INSTALL_MESSAGE="$3"
    local ARCHIVE="$ICON_NAME-icons.zip"

    # Download icons
    execute_command "wget -O $ARCHIVE '$DOWNLOAD_URL'" "Download icons $ICON_NAME"

    # Extract icons
    execute_command "unzip -o $ARCHIVE" "Extraction of icons $ICON_NAME"

    # Detect the name of the extracted directory
    local EXTRACTED_DIR=$(ls -d */ | grep -i "$ICON_NAME" | head -n 1)

    # Install icons
    execute_command "cd '$EXTRACTED_DIR' && \
                    ./install.sh -d $PREFIX/share/icons && \
                    cd .. && \
                    rm -rf '$EXTRACTED_DIR' $ARCHIVE" "$INSTALL_MESSAGE"
}

install_icons() {
    if $INSTALL_ICONS; then     
        # If it's a complete installation, set WhiteSur as the default icon theme
        if $FULL_INSTALL; then
            SELECTED_ICON_THEMES=("WhiteSur")
            SELECTED_ICON_THEME="WhiteSur"
        fi

        # Installation of selected icon themes
        for ICON_THEME in "${SELECTED_ICON_THEMES[@]}"; do
            case $ICON_THEME in
                "WhiteSur")
                    install_icon_pack "WhiteSur" "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.zip" "Install icons WhiteSur"
                    ;;
                "McMojave-circle")
                    install_icon_pack "McMojave-circle" "https://github.com/vinceliuice/McMojave-circle/archive/refs/heads/master.zip" "Install icons McMojave-circle"
                    ;;
                "Tela")
                    install_icon_pack "Tela" "https://github.com/vinceliuice/Tela-icon-theme/archive/refs/heads/master.zip" "Install icons Tela"
                    ;;
                "Fluent")
                    install_icon_pack "Fluent" "https://github.com/vinceliuice/Fluent-icon-theme/archive/refs/heads/master.zip" "Install icons Fluent"
                    ;;
                "Colloid")
                    install_icon_pack "Colloid" "https://github.com/vinceliuice/Colloid-icon-theme/archive/refs/heads/main.zip" "Install icons Colloid"
                    ;;
                "Qogir")
                    install_icon_pack "Qogir" "https://github.com/vinceliuice/Qogir-icon-theme/archive/refs/heads/master.zip" "Install icons Qogir"
                    ;;
            esac
        done
    fi
}

#------------------------------------------------------------------------------
# WALLPAPER INSTALLATION
#------------------------------------------------------------------------------
install_wallpapers() {
    if $INSTALL_WALLPAPERS; then
        ARCHIVE="2023-06-11.zip"
        download_file "https://github.com/vinceliuice/WhiteSur-wallpapers/archive/refs/tags/2023-06-11.zip" "Download wallpapers"
        execute_command "unzip $ARCHIVE && \
                        cd WhiteSur-wallpapers-2023-06-11 && \
                        ./install-wallpapers.sh && \
                        cd .. && \
                        rm -rf WhiteSur-wallpapers-2023-06-11 $ARCHIVE" "Install wallpapers"
    fi
}

#------------------------------------------------------------------------------
# CURSOR INSTALLATION
#------------------------------------------------------------------------------
install_cursors() {
    if $INSTALL_CURSORS; then
        ARCHIVE="2024-02-25.zip"
        download_file "https://github.com/vinceliuice/Fluent-icon-theme/archive/refs/tags/2024-02-25.zip" "Download cursors"
        execute_command "unzip $ARCHIVE && \
                        mv Fluent-icon-theme-2024-02-25/cursors/dist $PREFIX/share/icons/ && \
                        mv Fluent-icon-theme-2024-02-25/cursors/dist-dark $PREFIX/share/icons/ && \
                        rm -rf Fluent-icon-theme-2024-02-25 $ARCHIVE" "Install cursors"
    fi
}

#------------------------------------------------------------------------------
# MAIN FUNCTION
#------------------------------------------------------------------------------
main() {
    # Install gum if needed
    if $USE_GUM && ! command -v gum &> /dev/null; then
        echo -e "${COLOR_BLUE}Installation of gum${COLOR_RESET}"
        pkg update -y > /dev/null 2>&1 && pkg install gum -y > /dev/null 2>&1
    fi

    title_msg "❯ XFCE installation"

    execute_command "pkg update -y && pkg upgrade -y" "Update packages"

    # Base packages
    BASE_PKGS=(
        'termux-x11-nightly'         # X11 server for Termux
        'virglrenderer-android'      # Graphics acceleration
        'xfce4'                      # Graphical interface
        'xfce4-terminal'             # Terminal
    )

    # Recommended packages
    RECOMMENDED_PKGS=(
        'pavucontrol-qt'             # Sound control
        'wmctrl'                     # Window manager
        'netcat-openbsd'             # Network utility
        'thunar-archive-plugin'      # Archive manager
        'xfce4-whiskermenu-plugin'   # Whisker menu
        'xfce4-notifyd'              # Notifications
        'xfce4-screenshooter'        # Screenshot
        'xfce4-taskmanager'          # Task manager
    )

    # Optional packages
    EXTRA_PKGS=(
        'gigolo'                     # File manager
        'jq'                         # JSON utility
        'mousepad'                   # Text editor
        'netcat-openbsd'             # Network utility
        'parole'                     # Media player
        'pavucontrol-qt'             # Sound control
        'ristretto'                  # Image manager
        'thunar-archive-plugin'      # Archive manager
        'thunar-media-tags-plugin'   # Media manager
        'wmctrl'                     # Window manager
        'xfce4-artwork'              # Artwork
        'xfce4-battery-plugin'       # Battery
        'xfce4-clipman-plugin'       # Clipboard manager
        'xfce4-cpugraph-plugin'      # CPU graph
        'xfce4-datetime-plugin'      # Date and time
        'xfce4-dict'                 # Dictionary
        'xfce4-diskperf-plugin'      # Disk performance
        'xfce4-fsguard-plugin'       # Disk monitoring
        'xfce4-genmon-plugin'        # Generic widgets
        'xfce4-mailwatch-plugin'     # Mail monitoring
        'xfce4-netload-plugin'       # Network load
        'xfce4-notes-plugin'         # Notes
        'xfce4-notifyd'              # Notifications
        'xfce4-places-plugin'        # Locations
        'xfce4-screenshooter'        # Screenshot
        'xfce4-taskmanager'          # Task manager
        'xfce4-systemload-plugin'    # System load
        'xfce4-timer-plugin'         # Timer
        'xfce4-wavelan-plugin'       # Wi-Fi
        'xfce4-weather-plugin'       # Weather information
        'xfce4-whiskermenu-plugin'   # Whisker menu
    )

    case "$INSTALL_TYPE" in
        "minimal")
            PKGS=("${BASE_PKGS[@]}")
            ;;
        "recommended")
            INSTALL_THEME=true
            INSTALL_ICONS=true
            INSTALL_WALLPAPERS=true
            INSTALL_CURSORS=true
            SELECTED_THEMES=("WhiteSur")
            SELECTED_ICON_THEMES=("WhiteSur")
            SELECTED_THEME="WhiteSur"
            SELECTED_ICON_THEME="WhiteSur"
            SELECTED_WALLPAPER="Monterey"

            PKGS=("${BASE_PKGS[@]}" "${RECOMMENDED_PKGS[@]}")
            ;;
        "customized")
            PKGS=("${BASE_PKGS[@]}")

            if $USE_GUM; then
                SELECTED_EXTRA=($(gum_choose_multi "$(t "MSG_XFCE_SELECT_SPACE_PACKAGES")" --height=10 "${EXTRA_PKGS[@]}"))
                if [ ${#SELECTED_EXTRA[@]} -gt 0 ]; then
                    PKGS+=("${SELECTED_EXTRA[@]}")
                fi

                SELECTED_UI=($(gum_choose_multi "$(t "MSG_XFCE_SELECT_SPACE_ELEMENTS")" --height=6\
                    "Themes" \
                    "Icons" \
                    "Wallpapers" \
                    "Cursors"))

                if [[ " ${SELECTED_UI[*]} " =~ "Themes" ]]; then
                    SELECTED_THEMES=($(gum_choose_multi "$(t "MSG_XFCE_SELECT_SPACE_THEMES")" --height=5 \
                        "WhiteSur" \
                        "Fluent" \
                        "Lavanda"))

                    if [ ${#SELECTED_THEMES[@]} -gt 0 ]; then
                        INSTALL_THEME=true
                        if [ ${#SELECTED_THEMES[@]} -gt 1 ]; then
                            SELECTED_THEME=$(gum_choose "$(t "MSG_XFCE_SELECT_THEME")" "${SELECTED_THEMES[@]}" --height=5)
                        else
                            SELECTED_THEME="${SELECTED_THEMES[0]}"
                        fi
                    fi
                fi

                if [[ " ${SELECTED_UI[*]} " =~ "Icons" ]]; then
                    SELECTED_ICON_THEMES=($(gum_choose_multi "$(t "MSG_XFCE_SELECT_SPACE_ICONS")" --height=8 \
                        "WhiteSur" \
                        "McMojave-circle" \
                        "Tela" \
                        "Fluent" \
                        "Colloid" \
                        "Qogir"))

                    if [ ${#SELECTED_ICON_THEMES[@]} -gt 0 ]; then
                        INSTALL_ICONS=true
                        if [ ${#SELECTED_ICON_THEMES[@]} -gt 1 ]; then
                            SELECTED_ICON_THEME=$(gum_choose "$(t "MSG_XFCE_SELECT_ICONS")" "${SELECTED_ICON_THEMES[@]}" --height=8)
                        else
                            SELECTED_ICON_THEME="${SELECTED_ICON_THEMES[0]}"
                        fi
                    fi
                fi

                if [[ " ${SELECTED_UI[*]} " =~ "Wallpapers" ]]; then
                    INSTALL_WALLPAPERS=true
                    SELECTED_WALLPAPER=$(gum_choose "$(t "MSG_XFCE_SELECT_WALLPAPER")" --height=13 \
                        "Monterey" \
                        "Monterey-dark" \
                        "Monterey-light" \
                        "Monterey-morning" \
                        "Sonoma-dark" \
                        "Sonoma-light" \
                        "Ventura-dark" \
                        "Ventura-light" \
                        "WhiteSur" \
                        "WhiteSur-dark" \
                        "WhiteSur-light")
                fi

                [[ " ${SELECTED_UI[*]} " =~ "Cursors" ]] && INSTALL_CURSORS=true
            else
                echo -e "\n${COLOR_BLUE}$(t "MSG_XFCE_ADDITIONAL_PACKAGES")${COLOR_RESET}"
                for i in "${!EXTRA_PKGS[@]}"; do
                    echo "$((i+1))) ${EXTRA_PKGS[i]}"
                done
                echo
                printf "${COLOR_GOLD}$(t "MSG_XFCE_SELECT_PACKAGES") ${COLOR_RESET}"
                read -r CHOICES

                if [ "$CHOICES" = "a" ]; then
                    PKGS+=("${EXTRA_PKGS[@]}")
                else
                    for choice in $CHOICES; do
                        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#EXTRA_PKGS[@]}" ]; then
                            PKGS+=("${EXTRA_PKGS[$((choice-1))]}")
                        fi
                    done
                fi

                echo -e "\n${COLOR_BLUE}$(t "MSG_XFCE_GRAPHICAL_ELEMENTS")${COLOR_RESET}"
                echo "1) Themes"
                echo "2) Icons"
                echo "3) Wallpapers"
                echo "4) Cursors"
                echo
                printf "${COLOR_GOLD}$(t "MSG_XFCE_SELECT_ELEMENTS") ${COLOR_RESET}"
                read -r UI_CHOICES

                if [[ $UI_CHOICES =~ 1 ]]; then
                    echo -e "\n${COLOR_BLUE}$(t "MSG_XFCE_THEMES_AVAILABLE")${COLOR_RESET}"
                    echo "1) WhiteSur"
                    echo "2) Fluent"
                    echo "3) Lavanda"
                    echo
                    printf "${COLOR_GOLD}$(t "MSG_XFCE_SELECT_THEMES") ${COLOR_RESET}"
                    read -r THEME_CHOICES

                    for choice in $THEME_CHOICES; do
                        case $choice in
                            1) SELECTED_THEMES+=("WhiteSur") ;;
                            2) SELECTED_THEMES+=("Fluent") ;;
                            3) SELECTED_THEMES+=("Lavanda") ;;
                        esac
                    done

                    if [ ${#SELECTED_THEMES[@]} -gt 0 ]; then
                        INSTALL_THEME=true
                        if [ ${#SELECTED_THEMES[@]} -gt 1 ]; then
                            echo -e "\n${COLOR_BLUE}$(t "MSG_XFCE_THEMES_SELECTED")${COLOR_RESET}"
                            for i in "${!SELECTED_THEMES[@]}"; do
                                echo "$((i+1))) ${SELECTED_THEMES[i]}"
                            done
                            echo
                            printf "${COLOR_GOLD}$(t "MSG_XFCE_SELECT_THEME_APPLY") (1-${#SELECTED_THEMES[@]}) : ${COLOR_RESET}"
                            read -r THEME_CHOICE
                            SELECTED_THEME="${SELECTED_THEMES[$((THEME_CHOICE-1))]}"
                        else
                            SELECTED_THEME="${SELECTED_THEMES[0]}"
                        fi
                    fi
                fi

                if [[ $UI_CHOICES =~ 2 ]]; then
                    echo -e "\n${COLOR_BLUE}$(t "MSG_XFCE_ICON_PACKS_AVAILABLE")${COLOR_RESET}"
                    echo "1) WhiteSur"
                    echo "2) McMojave-circle"
                    echo "3) Tela"
                    echo "4) Fluent"
                    echo "5) Qogir"
                    echo
                    printf "${COLOR_GOLD}$(t "MSG_XFCE_SELECT_ICON_PACKS") ${COLOR_RESET}"
                    read -r ICON_CHOICES

                    for choice in $ICON_CHOICES; do
                        case $choice in
                            1) SELECTED_ICON_THEMES+=("WhiteSur") ;;
                            2) SELECTED_ICON_THEMES+=("McMojave-circle") ;;
                            3) SELECTED_ICON_THEMES+=("Tela") ;;
                            4) SELECTED_ICON_THEMES+=("Fluent") ;;
                            5) SELECTED_ICON_THEMES+=("Qogir") ;;
                        esac
                    done

                    if [ ${#SELECTED_ICON_THEMES[@]} -gt 0 ]; then
                        INSTALL_ICONS=true
                        if [ ${#SELECTED_ICON_THEMES[@]} -gt 1 ]; then
                            echo -e "\n${COLOR_BLUE}$(t "MSG_XFCE_ICON_PACKS_SELECTED")${COLOR_RESET}"
                            for i in "${!SELECTED_ICON_THEMES[@]}"; do
                                echo "$((i+1))) ${SELECTED_ICON_THEMES[i]}"
                            done
                            echo
                            printf "${COLOR_GOLD}$(t "MSG_XFCE_SELECT_ICON_APPLY") (1-${#SELECTED_ICON_THEMES[@]}) : ${COLOR_RESET}"
                            read -r ICON_CHOICE
                            SELECTED_ICON_THEME="${SELECTED_ICON_THEMES[$((ICON_CHOICE-1))]}"
                        else
                            SELECTED_ICON_THEME="${SELECTED_ICON_THEMES[0]}"
                        fi
                    fi
                fi

                if [[ $UI_CHOICES =~ 3 ]]; then
                    INSTALL_WALLPAPERS=true
                    echo -e "\n${COLOR_BLUE}$(t "MSG_XFCE_WALLPAPERS_AVAILABLE")${COLOR_RESET}"
                    echo "1) Monterey"
                    echo "2) Monterey-dark"
                    echo "3) Monterey-light"
                    echo "4) Monterey-morning"
                    echo "5) Sonoma-dark"
                    echo "6) Sonoma-light"
                    echo "7) Ventura-dark"
                    echo "8) Ventura-light"
                    echo "9) WhiteSur"
                    echo "10) WhiteSur-dark"
                    echo "11) WhiteSur-light"
                    echo
                    printf "${COLOR_GOLD}$(t "MSG_XFCE_SELECT_WALLPAPER_APPLY") (1-11) : ${COLOR_RESET}"
                    read -r WALLPAPER_CHOICE

                    case $WALLPAPER_CHOICE in
                        1) SELECTED_WALLPAPER="Monterey" ;;
                        2) SELECTED_WALLPAPER="Monterey-dark" ;;
                        3) SELECTED_WALLPAPER="Monterey-light" ;;
                        4) SELECTED_WALLPAPER="Monterey-morning" ;;
                        5) SELECTED_WALLPAPER="Sonoma-dark" ;;
                        6) SELECTED_WALLPAPER="Sonoma-light" ;;
                        7) SELECTED_WALLPAPER="Ventura-dark" ;;
                        8) SELECTED_WALLPAPER="Ventura-light" ;;
                        9) SELECTED_WALLPAPER="WhiteSur" ;;
                        10) SELECTED_WALLPAPER="WhiteSur-dark" ;;
                        11) SELECTED_WALLPAPER="WhiteSur-light" ;;
                    esac
                fi

                [[ $UI_CHOICES =~ 4 ]] && INSTALL_CURSORS=true
            fi
            ;;
    esac

    # Packages installation
    subtitle_msg "❯ Packages installation"
    for PKG in "${PKGS[@]}"; do
        execute_command "pkg install $PKG -y" "Installation of $PKG"
    done

    # Browser installation
    if [ "$BROWSER" = "firefox" ]; then
        execute_command "pkg install firefox -y" "Firefox installation"
        execute_command "mkdir -p $HOME/Desktop && cp $PREFIX/share/applications/firefox.desktop $HOME/Desktop && chmod +x $HOME/Desktop/firefox.desktop" "Firefox shortcut configuration"
    elif [ "$BROWSER" = "chromium" ]; then
        execute_command "pkg install chromium -y" "Chromium installation"
        execute_command "mkdir -p $HOME/Desktop && cp $PREFIX/share/applications/chromium.desktop $HOME/Desktop && chmod +x $HOME/Desktop/chromium.desktop" "Chromium shortcut configuration"
    fi

    # XFCE elements installation
    if [ "$INSTALL_TYPE" != "minimal" ]; then
        subtitle_msg "❯ XFCE elements installation"
        [ "$INSTALL_THEME" = true ] && install_themes
        [ "$INSTALL_ICONS" = true ] && install_icons
        [ "$INSTALL_WALLPAPERS" = true ] && install_wallpapers
        [ "$INSTALL_CURSORS" = true ] && install_cursors
    fi

    # XFCE pre-configuration
    download_file "https://github.com/devohmycode/OhMyTermux/raw/$BRANCH/src/config.zip" "XFCE configuration download"
    execute_command "unzip -o config.zip && \
                rm config.zip" "XFCE configuration installation"

    # XFCE configuration
    configure_xfce

    # Theme configuration save
    save_theme_config
}

main "$@"