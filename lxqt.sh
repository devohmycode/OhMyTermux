#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GitHub branch for downloads
BRANCH="1.2.2"

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

    # Save desktop session for start/stop scripts
    echo "DESKTOP_SESSION=lxqt" > "$OHMYTERMUX_CONFIG_DIR/desktop.conf"
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

    # Update the start script for LXQt
    title_msg "$(t MSG_LXQT_INSTALL_LXQT) - start"
    _update_start_script

    success_msg "$(t MSG_LXQT_INSTALL_LXQT) ✓"
}

#------------------------------------------------------------------------------
# UPDATE START / STOP SCRIPTS FOR LXQT
#------------------------------------------------------------------------------
_update_start_script() {
    info_msg "$(t MSG_LXQT_BASE_CONFIG) - start/stop"

    # Write the start script
    cat > "$PREFIX/bin/start" << 'STARTEOF'
#!/bin/bash

# ---------------------------------------------------------------------------
# OhMyTermux - start
# Démarre Termux-X11 avec XFCE ou LXQt selon l'environnement installé
# ---------------------------------------------------------------------------

OHMYTERMUX_CONFIG="$HOME/.config/OhMyTermux"

# ---------------------------------------------------------------------------
# NETTOYAGE DU SERVEUR X EXISTANT
# ---------------------------------------------------------------------------
pkill -f "termux.x11"   > /dev/null 2>&1
pkill -f "Xwayland"     > /dev/null 2>&1
pkill -f "xfce4-session"> /dev/null 2>&1
pkill -f "lxqt-session" > /dev/null 2>&1
pkill -f "startlxqt"    > /dev/null 2>&1
pkill -f "openbox"      > /dev/null 2>&1
sleep 1

# Supprimer les verrous X11 résiduels
rm -f /tmp/.X1-lock          > /dev/null 2>&1
rm -f /tmp/.X11-unix/X1      > /dev/null 2>&1

# ---------------------------------------------------------------------------
# DÉTECTER L'ENVIRONNEMENT DE BUREAU
# ---------------------------------------------------------------------------
DESKTOP_SESSION="unknown"

# 1. Lire depuis desktop.conf (priorité haute - écrit par install.sh / lxqt.sh)
if [ -f "$OHMYTERMUX_CONFIG/desktop.conf" ]; then
    source "$OHMYTERMUX_CONFIG/desktop.conf"
fi

# 2. Fallback : lire depuis theme_config.tmp (écrit par lxqt.sh)
if [ "$DESKTOP_SESSION" = "unknown" ] || [ -z "$DESKTOP_SESSION" ]; then
    if [ -f "$OHMYTERMUX_CONFIG/theme_config.tmp" ]; then
        DETECTED=$(grep '^DESKTOP_ENV=' "$OHMYTERMUX_CONFIG/theme_config.tmp" | cut -d'=' -f2 | tr -d '"')
        [ -n "$DETECTED" ] && DESKTOP_SESSION="$DETECTED"
    fi
fi

# 3. Fallback final : détecter par la présence des binaires
if [ "$DESKTOP_SESSION" = "unknown" ] || [ -z "$DESKTOP_SESSION" ]; then
    if command -v startlxqt > /dev/null 2>&1 || command -v lxqt-session > /dev/null 2>&1; then
        DESKTOP_SESSION="lxqt"
    elif command -v xfce4-session > /dev/null 2>&1; then
        DESKTOP_SESSION="xfce"
    else
        echo "[start] Aucun environnement de bureau détecté (xfce4-session ou startlxqt)."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# PULSEAUDIO
# ---------------------------------------------------------------------------
pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1 > /dev/null 2>&1

export PULSE_SERVER=127.0.0.1

# ---------------------------------------------------------------------------
# DÉMARRER TERMUX-X11
# ---------------------------------------------------------------------------
XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :1.0 &> /dev/null &
sleep 1

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

# ---------------------------------------------------------------------------
# VIRGL (rendu GPU)
# ---------------------------------------------------------------------------
GPU_VENDOR="unknown"
if [ -f "$OHMYTERMUX_CONFIG/gpu_vendor" ]; then
    GPU_VENDOR=$(cat "$OHMYTERMUX_CONFIG/gpu_vendor")
fi

if [ "$GPU_VENDOR" = "adreno" ]; then
    MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 \
        virgl_test_server_android --angle-gl &> /dev/null &
else
    MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 \
        virgl_test_server_android &> /dev/null &
fi
sleep 1

# ---------------------------------------------------------------------------
# DÉMARRER LA SESSION DE BUREAU
# ---------------------------------------------------------------------------
export DISPLAY=:1.0
export GALLIUM_DRIVER=virpipe

case "$DESKTOP_SESSION" in
    lxqt)
        env DISPLAY=:1.0 GALLIUM_DRIVER=virpipe \
            dbus-launch --exit-with-session startlxqt &> /dev/null &
        sleep 5
        process_id=$(ps -aux | grep '[x]screensaver' | awk '{print $2}')
        [ -n "$process_id" ] && kill "$process_id" > /dev/null 2>&1
        ;;
    xfce)
        env DISPLAY=:1.0 GALLIUM_DRIVER=virpipe \
            dbus-launch --exit-with-session xfce4-session &> /dev/null &
        sleep 5
        process_id=$(ps -aux | grep '[x]fce4-screensaver' | awk '{print $2}')
        [ -n "$process_id" ] && kill "$process_id" > /dev/null 2>&1
        ;;
    *)
        echo "[start] Environnement de bureau non reconnu : $DESKTOP_SESSION"
        echo "        Valeurs acceptées : xfce, lxqt"
        exit 1
        ;;
esac
STARTEOF

    chmod +x "$PREFIX/bin/start"

    # Update the stop script to handle both XFCE and LXQt
    cat > "$PREFIX/bin/kill_termux_x11" << STOPEOF
#!/bin/bash

OHMYTERMUX_CONFIG="\$HOME/.config/OhMyTermux"
DESKTOP_SESSION="lxqt"
[ -f "\$OHMYTERMUX_CONFIG/desktop.conf" ] && source "\$OHMYTERMUX_CONFIG/desktop.conf"

if pgrep -f 'apt|apt-get|dpkg|nala' > /dev/null; then
    zenity --info --text="A software is being installed. Please wait before stopping the session."
    exit 1
fi

termux_x11_pid=\$(pgrep -f /system/bin/app_process.*com.termux.x11.Loader)
virgl_pid=\$(pgrep -f "virgl_test_server")

case "\$DESKTOP_SESSION" in
    lxqt)
        de_pid=\$(pgrep -f "lxqt-session")
        ob_pid=\$(pgrep -f "openbox")
        de_name="LXQt"
        ;;
    *)
        de_pid=\$(pgrep -f "xfce4-session")
        ob_pid=""
        de_name="XFCE"
        ;;
esac

[ -n "\$termux_x11_pid" ] && kill -9 "\$termux_x11_pid" 2>/dev/null
[ -n "\$de_pid"          ] && kill -9 "\$de_pid"         2>/dev/null
[ -n "\$ob_pid"          ] && kill -9 "\$ob_pid"         2>/dev/null
[ -n "\$virgl_pid"       ] && kill -9 "\$virgl_pid"      2>/dev/null

rm -f /tmp/.X1-lock       2>/dev/null
rm -f /tmp/.X11-unix/X1   2>/dev/null

if [ -n "\$termux_x11_pid" ] || [ -n "\$de_pid" ]; then
    zenity --info --text="Termux-X11 and \$de_name sessions closed."
else
    zenity --info --text="Termux-X11 or \$de_name session not found."
fi

info_output=\$(termux-info)
if pid=\$(echo "\$info_output" | grep -o 'TERMUX_APP_PID=[0-9]\+' | awk -F= '{print \$2}') && [ -n "\$pid" ]; then
    kill "\$pid" 2>/dev/null
fi

exit 0
STOPEOF

    chmod +x "$PREFIX/bin/kill_termux_x11"
}

# Run main
main
