#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GitHub branch for downloads
BRANCH="1.2.1"

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

#------------------------------------------------------------------------------
# BOOTSTRAP - Load i18n and lib systems
#------------------------------------------------------------------------------
_loader_url="https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/lib/i18n_loader.sh"
mkdir -p "$SCRIPT_DIR/lib"
if [ ! -f "$SCRIPT_DIR/lib/i18n_loader.sh" ]; then
    curl -fL -s -o "$SCRIPT_DIR/lib/i18n_loader.sh" "$_loader_url" 2>/dev/null
fi
source "$SCRIPT_DIR/lib/i18n_loader.sh"

#------------------------------------------------------------------------------
# GLOBAL VARIABLES
#------------------------------------------------------------------------------
USE_GUM=false
VERBOSE=false
BROWSER="chromium"

# Configure error handler keys for this script
ERROR_MSG_KEY="MSG_LXQT_ERROR_INSTALL"
ERROR_REFER_KEY="MSG_LXQT_ERROR_REFER"

#------------------------------------------------------------------------------
# DISPLAY HELP
#------------------------------------------------------------------------------
show_help() {
    clear
    echo "$(t "MSG_LXQT_HELP_TITLE")"
    echo
    echo "$(t "MSG_LXQT_HELP_USAGE")"
    echo "$(t "MSG_LXQT_HELP_OPTIONS")"
    echo "  --gum | -g        $(t "MSG_LXQT_HELP_GUM")"
    echo "  --verbose | -v    $(t "MSG_LXQT_HELP_VERBOSE")"
    echo "  --browser | -b    $(t "MSG_LXQT_HELP_BROWSER")"
    echo "  --version | -ver  $(t "MSG_LXQT_HELP_VERSION")"
    echo "  --full            $(t "MSG_LXQT_HELP_FULL")"
    echo "  --help | -h       $(t "MSG_LXQT_HELP_HELP")"
}

#------------------------------------------------------------------------------
# CUSTOM VARIABLES
#------------------------------------------------------------------------------
INSTALL_THEME=false
INSTALL_ICONS=false
INSTALL_CURSORS=false
SELECTED_ICON_THEME="Papirus"

#------------------------------------------------------------------------------
# COMPLETE VARIABLES
#------------------------------------------------------------------------------
FULL_INSTALL=false
LXQT_VERSION=""
BROWSER_CHOICE=""

#------------------------------------------------------------------------------
# ARGUMENTS MANAGEMENT
#------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --gum|-g)
            USE_GUM=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            REDIRECT=""
            shift
            ;;
        --browser=*|-b=*)
            BROWSER="${1#*=}"
            BROWSER_CHOICE="${1#*=}"
            shift
            ;;
        --version=*|-ver=*)
            LXQT_VERSION="${1#*=}"
            shift
            ;;
        --full)
            FULL_INSTALL=true
            LXQT_VERSION="recommended"
            BROWSER_CHOICE="chromium"
            shift
            ;;
        --lang|-l)
            shift
            [ -n "$1" ] && shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

#------------------------------------------------------------------------------
# PACKAGE DEFINITIONS
#------------------------------------------------------------------------------
BASE_PKGS=(
    'termux-x11-nightly'
    'virglrenderer-android'
    'lxqt'
    'qterminal'
    'pcmanfm-qt'
    'openbox'
    'obconf-qt'
)

RECOMMENDED_PKGS=(
    'pavucontrol-qt'
    'lxqt-archiver'
    'lximage-qt'
    'featherpad'
    'qps'
    'kvantum'
    'wmctrl'
    'netcat-openbsd'
)

#------------------------------------------------------------------------------
# BROWSER CONFIGURATION
#------------------------------------------------------------------------------
configure_browser() {
    local browser_name="$1"

    mkdir -p "$HOME/.local/share/applications"

    # Set default browser in mimeapps.list
    cat > "$HOME/.local/share/applications/mimeapps.list" << MIMEEOF
[Default Applications]
x-scheme-handler/http=${browser_name}.desktop
x-scheme-handler/https=${browser_name}.desktop
text/html=${browser_name}.desktop
MIMEEOF
}

#------------------------------------------------------------------------------
# LXQT CONFIGURATION
#------------------------------------------------------------------------------
configure_lxqt() {
    local version="$1"
    local browser="$2"

    info_msg "$(t MSG_LXQT_BASE_CONFIG)"

    # Create config directories
    mkdir -p "$HOME/.config/lxqt"
    mkdir -p "$HOME/.config/openbox"
    mkdir -p "$HOME/.config/qterminal.org"
    mkdir -p "$HOME/.config/Kvantum"

    # Configure browser
    if [ "$browser" != "none" ] && [ -n "$browser" ]; then
        configure_browser "$browser"
    fi

    # Generate lxqt.conf
    info_msg "$(t MSG_LXQT_GENERATE_LXQT_CONF)"
    cat > "$HOME/.config/lxqt/lxqt.conf" << 'LXQTCONF'
[General]
__userfile__=true

[Appearance]
icon_theme=Papirus
cursor_theme=default
cursor_size=24

[Session]
window_manager=openbox
LXQTCONF

    # Generate session.conf
    info_msg "$(t MSG_LXQT_GENERATE_SESSION_CONF)"
    cat > "$HOME/.config/lxqt/session.conf" << 'SESSIONCONF'
[General]
__userfile__=true
window_manager=openbox

[Environment]
TERM=xterm-256color
SESSIONCONF

    # Generate panel.conf
    info_msg "$(t MSG_LXQT_GENERATE_PANEL_CONF)"
    cat > "$HOME/.config/lxqt/panel.conf" << 'PANELCONF'
[General]
__userfile__=true

[panel1]
alignment=Left
animation-duration=0
background-color=rgba(0, 0, 0, 0)
background-widget=
desktop=0
font-color=#FFFFFF
hide-on-overlap=false
hidable=false
iconSize=32
lineCount=1
lockPanel=false
panelSize=48
position=Bottom
reserve-space=true
show-delay=0
visible-margin=true
width=100
width-percent=true

[panel1/Plugin#0]
alignment=Left
type=mainmenu

[panel1/Plugin#1]
alignment=Left
type=taskbar

[panel1/Plugin#2]
alignment=Right
type=tray

[panel1/Plugin#3]
alignment=Right
type=volume

[panel1/Plugin#4]
alignment=Right
type=worldclock
PANELCONF

    # Generate openbox lxqt-rc.xml
    info_msg "$(t MSG_LXQT_GENERATE_OPENBOX_RC)"
    cat > "$HOME/.config/openbox/lxqt-rc.xml" << 'OBRC'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>
  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
    <primaryMonitor>1</primaryMonitor>
  </placement>
  <theme>
    <name>Clearlooks</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
    <font place="ActiveWindow">
      <name>sans</name>
      <size>10</size>
      <weight>bold</weight>
      <slant>normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>sans</name>
      <size>10</size>
      <weight>bold</weight>
      <slant>normal</slant>
    </font>
  </theme>
  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Desktop</name>
    </names>
    <popupTime>875</popupTime>
  </desktops>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
  </keyboard>
  <mouse>
    <dragThreshold>1</dragThreshold>
    <doubleClickTime>500</doubleClickTime>
    <screenEdgeWarpTime>400</screenEdgeWarpTime>
    <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
  </mouse>
</openbox_config>
OBRC

    # Configure qterminal
    info_msg "$(t MSG_LXQT_CONFIGURE_TERMINAL)"
    cat > "$HOME/.config/qterminal.org/qterminal.ini" << 'QTERMCONF'
[General]
AskOnExit=false
BoldIntense=true
BorderWidth=0
ChangeFontSize=1.5
Emulation=default
FixedTabWidth=false
FixedTabWidthValue=500
FontAntialias=true
HideTabBar=true
HistoryLimited=true
HistoryLimitedTo=1000
KeyboardCursorShape=0
LastWindowMaximized=false
Scrollbar=2
TabBarless=false
Term=xterm-256color
TerminalMargin=0
UseFontBoxDrawingChars=false
colorScheme=Linux
enabledBidiSupport=true
fontFamily=Monospace
fontSize=12
guiStyle=
highlightCurrentTerminal=false
showTerminalSizeHint=true
version=1.4
QTERMCONF

    # Configure Kvantum for recommended mode
    if [ "$version" = "recommended" ]; then
        info_msg "$(t MSG_LXQT_CONFIGURE_KVANTUM)"
        cat > "$HOME/.config/Kvantum/kvantum.kvconfig" << 'KVCONF'
[General]
theme=KvDarkFresh
KVCONF
    fi

    # Save theme config for proot.sh consumption
    mkdir -p "$OHMYTERMUX_CONFIG_DIR" 2>/dev/null
    cat > "$OHMYTERMUX_CONFIG_DIR/theme_config.tmp" << THEMECONF
INSTALL_THEME=$INSTALL_THEME
INSTALL_ICONS=true
INSTALL_WALLPAPERS=false
INSTALL_CURSORS=$INSTALL_CURSORS
SELECTED_THEME=""
SELECTED_ICON_THEME="Papirus"
SELECTED_WALLPAPER=""
DESKTOP_ENV=lxqt
THEMECONF
}

#------------------------------------------------------------------------------
# INSTALL ICONS (Papirus)
#------------------------------------------------------------------------------
install_icons() {
    info_msg "$(t MSG_LXQT_INSTALL_ICONS)"
    execute_command "pkg install -y papirus-icon-theme" "$(t MSG_LXQT_INSTALLATION_OF) Papirus"
}

#------------------------------------------------------------------------------
# INSTALL BROWSER
#------------------------------------------------------------------------------
install_browser() {
    local browser="$1"
    case "$browser" in
        chromium)
            execute_command "pkg install -y chromium" "$(t MSG_LXQT_CHROMIUM_INSTALLATION)"
            ;;
        firefox)
            execute_command "pkg install -y firefox" "$(t MSG_LXQT_FIREFOX_INSTALLATION)"
            ;;
    esac
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------
main() {
    title_msg "$(t MSG_LXQT_INSTALL_LXQT)"

    # Update packages
    execute_command "pkg update -y" "$(t MSG_LXQT_UPDATE_PACKAGES)"

    # Install base packages
    subtitle_msg "$(t MSG_LXQT_BASE_PACKAGES)"
    for pkg in "${BASE_PKGS[@]}"; do
        execute_command "pkg install -y $pkg" "$(t MSG_LXQT_INSTALLATION_OF) $pkg"
    done

    # Install recommended packages if version is recommended
    if [ "$LXQT_VERSION" = "recommended" ]; then
        subtitle_msg "$(t MSG_LXQT_RECOMMENDED_PACKAGES)"
        for pkg in "${RECOMMENDED_PKGS[@]}"; do
            execute_command "pkg install -y $pkg" "$(t MSG_LXQT_INSTALLATION_OF) $pkg"
        done
    fi

    # Install browser
    if [ "$BROWSER_CHOICE" != "none" ] && [ -n "$BROWSER_CHOICE" ]; then
        install_browser "$BROWSER_CHOICE"
    fi

    # Install icons for recommended mode
    if [ "$LXQT_VERSION" = "recommended" ]; then
        install_icons
    fi

    # Configure LXQt
    title_msg "$(t MSG_LXQT_ELEMENTS_INSTALLATION)"
    configure_lxqt "$LXQT_VERSION" "$BROWSER_CHOICE"

    success_msg "$(t MSG_LXQT_INSTALL_LXQT) ✓"
}

# Run main
main
