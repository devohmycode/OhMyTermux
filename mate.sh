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
# Always try to refresh i18n_loader.sh; fall back to cached version if download fails
_loader_tmp=$(mktemp 2>/dev/null || echo "$SCRIPT_DIR/lib/i18n_loader.sh.tmp")
if curl -fL -s -o "$_loader_tmp" "$_loader_url" 2>/dev/null && head -1 "$_loader_tmp" 2>/dev/null | grep -q "^#!/bin/bash"; then
    mv "$_loader_tmp" "$SCRIPT_DIR/lib/i18n_loader.sh"
else
    rm -f "$_loader_tmp" 2>/dev/null
    if [ ! -f "$SCRIPT_DIR/lib/i18n_loader.sh" ]; then
        echo "Warning: Could not download i18n_loader.sh and no cached version available" >&2
    fi
fi
source "$SCRIPT_DIR/lib/i18n_loader.sh"

#------------------------------------------------------------------------------
# GLOBAL VARIABLES
#------------------------------------------------------------------------------
USE_GUM=false
VERBOSE=false
BROWSER="chromium"
REDIRECT=">/dev/null 2>&1"

# Configure error handler keys for this script
ERROR_MSG_KEY="MSG_MATE_ERROR_INSTALL"
ERROR_REFER_KEY="MSG_MATE_ERROR_REFER"

#------------------------------------------------------------------------------
# DISPLAY HELP
#------------------------------------------------------------------------------
show_help() {
    clear
    echo "$(t "MSG_MATE_HELP_TITLE")"
    echo
    echo "$(t "MSG_MATE_HELP_USAGE")"
    echo "$(t "MSG_MATE_HELP_OPTIONS")"
    echo "  --gum | -g        $(t "MSG_MATE_HELP_GUM")"
    echo "  --verbose | -v    $(t "MSG_MATE_HELP_VERBOSE")"
    echo "  --browser | -b    $(t "MSG_MATE_HELP_BROWSER")"
    echo "  --version | -ver  $(t "MSG_MATE_HELP_VERSION")"
    echo "  --full            $(t "MSG_MATE_HELP_FULL")"
    echo "  --help | -h       $(t "MSG_MATE_HELP_HELP")"
}

#------------------------------------------------------------------------------
# INSTALLATION VARIABLES
#------------------------------------------------------------------------------
FULL_INSTALL=false
MATE_VERSION=""
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
            MATE_VERSION="${1#*=}"
            shift
            ;;
        --full)
            FULL_INSTALL=true
            MATE_VERSION="recommended"
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
    'mate-session-manager'
    'mate-settings-daemon'
    'mate-panel'
    'marco'
    'caja'
    'mate-terminal'
    'mate-desktop'
    'mate-menus'
    'dbus'
)

RECOMMENDED_PKGS=(
    'pluma'
    'engrampa'
    'eom'
    'mate-applet-brisk-menu'
    'pavucontrol'
    'mousepad'
    'netcat-openbsd'
    'wmctrl'
)

#------------------------------------------------------------------------------
# BROWSER CONFIGURATION
#------------------------------------------------------------------------------
configure_browser() {
    local browser_name="$1"

    mkdir -p "$HOME/.local/share/applications"

    cat > "$HOME/.local/share/applications/mimeapps.list" << MIMEEOF
[Default Applications]
x-scheme-handler/http=${browser_name}.desktop
x-scheme-handler/https=${browser_name}.desktop
text/html=${browser_name}.desktop
application/xhtml+xml=${browser_name}.desktop
MIMEEOF
}

#------------------------------------------------------------------------------
# MATE CONFIGURATION
#------------------------------------------------------------------------------
configure_mate() {
    local version="$1"
    local browser="$2"

    info_msg "$(t MSG_MATE_BASE_CONFIG)"

    # Create config directories
    mkdir -p "$HOME/.config/mate"
    mkdir -p "$HOME/.config/dconf"
    mkdir -p "$HOME/.local/share/applications"
    mkdir -p "$HOME/.local/share/mate/panel2.d/default/launchers"

    # Configure browser
    if [ "$browser" != "none" ] && [ -n "$browser" ]; then
        configure_browser "$browser"
    fi

    # Configure mate-terminal
    info_msg "$(t MSG_MATE_CONFIGURE_TERMINAL)"
    mkdir -p "$HOME/.config/mate/terminal"

    # Generate dconf settings for MATE
    info_msg "$(t MSG_MATE_GENERATE_DCONF)"

    # Apply MATE dconf settings via gsettings (if available) or dconf
    # Marco window manager settings
    if command -v gsettings &>/dev/null; then
        gsettings set org.mate.Marco.general theme 'TraditionalOk' 2>/dev/null || true
        gsettings set org.mate.Marco.general button-layout 'menu:minimize,maximize,close' 2>/dev/null || true
        gsettings set org.mate.Marco.general num-workspaces 2 2>/dev/null || true

        # Panel settings
        gsettings set org.mate.panel default-layout 'default' 2>/dev/null || true

        # Interface settings
        gsettings set org.mate.interface gtk-theme 'TraditionalOk' 2>/dev/null || true
        gsettings set org.mate.interface icon-theme 'Papirus' 2>/dev/null || true
        gsettings set org.mate.interface cursor-theme 'default' 2>/dev/null || true
        gsettings set org.mate.interface font-name 'Sans 10' 2>/dev/null || true
        gsettings set org.mate.interface document-font-name 'Sans 10' 2>/dev/null || true
        gsettings set org.mate.interface monospace-font-name 'Monospace 10' 2>/dev/null || true

        # Terminal settings
        gsettings set org.mate.terminal.global default-profile 'default' 2>/dev/null || true
    fi

    # Generate a minimal MATE autostart entry to disable screensaver
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/disable-screensaver.desktop" << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Disable Screensaver
Exec=xset s off -dpms
Hidden=false
NoDisplay=true
X-MATE-Autostart-enabled=true
AUTOSTART

    # GTK2 theme configuration
    cat > "$HOME/.gtkrc-2.0" << 'GTKRC'
gtk-theme-name="TraditionalOk"
gtk-icon-theme-name="Papirus"
gtk-font-name="Sans 10"
gtk-cursor-theme-name="default"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintfull"
gtk-xft-rgba="rgb"
GTKRC

    # GTK3 settings
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << 'GTK3SETTINGS'
[Settings]
gtk-theme-name=TraditionalOk
gtk-icon-theme-name=Papirus
gtk-font-name=Sans 10
gtk-cursor-theme-name=default
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=false
gtk-menu-images=false
gtk-enable-event-sounds=true
gtk-enable-input-feedback-sounds=false
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=rgb
GTK3SETTINGS

    # Save theme config
    mkdir -p "$OHMYTERMUX_CONFIG_DIR" 2>/dev/null
    cat > "$OHMYTERMUX_CONFIG_DIR/theme_config.tmp" << THEMECONF
INSTALL_THEME=false
INSTALL_ICONS=true
INSTALL_WALLPAPERS=false
INSTALL_CURSORS=false
SELECTED_THEME=""
SELECTED_ICON_THEME="Papirus"
SELECTED_WALLPAPER=""
DESKTOP_ENV=mate
THEMECONF

    # Save desktop session
    echo "DESKTOP_SESSION=mate" > "$OHMYTERMUX_CONFIG_DIR/desktop.conf"
}

#------------------------------------------------------------------------------
# INSTALL ICONS (Papirus)
#------------------------------------------------------------------------------
install_icons() {
    info_msg "$(t MSG_MATE_INSTALL_ICONS)"
    execute_command "pkg install -y papirus-icon-theme" "$(t MSG_MATE_INSTALLATION_OF) Papirus"
}

#------------------------------------------------------------------------------
# INSTALL BROWSER
#------------------------------------------------------------------------------
install_browser() {
    local browser="$1"
    case "$browser" in
        chromium)
            execute_command "pkg install -y chromium" "$(t MSG_MATE_CHROMIUM_INSTALLATION)"
            ;;
        firefox)
            execute_command "pkg install -y firefox" "$(t MSG_MATE_FIREFOX_INSTALLATION)"
            ;;
    esac
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------
main() {
    title_msg "$(t MSG_MATE_INSTALL_MATE)"

    # Update packages
    execute_command "pkg update -y" "$(t MSG_MATE_UPDATE_PACKAGES)"

    # Install base packages
    subtitle_msg "$(t MSG_MATE_BASE_PACKAGES)"
    for pkg in "${BASE_PKGS[@]}"; do
        execute_command "pkg install -y $pkg" "$(t MSG_MATE_INSTALLATION_OF) $pkg"
    done

    # Install recommended packages
    if [ "$MATE_VERSION" = "recommended" ]; then
        subtitle_msg "$(t MSG_MATE_RECOMMENDED_PACKAGES)"
        for pkg in "${RECOMMENDED_PKGS[@]}"; do
            execute_command "pkg install -y $pkg" "$(t MSG_MATE_INSTALLATION_OF) $pkg"
        done
    fi

    # Install browser
    if [ "$BROWSER_CHOICE" != "none" ] && [ -n "$BROWSER_CHOICE" ]; then
        install_browser "$BROWSER_CHOICE"
    fi

    # Install icons
    install_icons

    # Configure MATE
    title_msg "$(t MSG_MATE_ELEMENTS_INSTALLATION)"
    configure_mate "$MATE_VERSION" "$BROWSER_CHOICE"

    # Update the start/stop scripts for MATE
    title_msg "$(t MSG_MATE_INSTALL_MATE) - start"
    _update_start_script

    success_msg "$(t MSG_MATE_INSTALL_MATE) ✓"
}

#------------------------------------------------------------------------------
# UPDATE START / STOP SCRIPTS FOR MATE
#------------------------------------------------------------------------------
_update_start_script() {
    info_msg "$(t MSG_MATE_BASE_CONFIG) - start/stop"

    cat > "$PREFIX/bin/start" << 'STARTEOF'
#!/bin/bash

# ---------------------------------------------------------------------------
# OhMyTermux - start
# Starts Termux-X11 with XFCE, LXQt or MATE depending on installed environment
# ---------------------------------------------------------------------------

OHMYTERMUX_CONFIG="$HOME/.config/OhMyTermux"

# ---------------------------------------------------------------------------
# CLEAN UP EXISTING X SERVER
# ---------------------------------------------------------------------------
pkill -f "termux.x11"    > /dev/null 2>&1
pkill -f "Xwayland"      > /dev/null 2>&1
pkill -f "xfce4-session" > /dev/null 2>&1
pkill -f "lxqt-session"  > /dev/null 2>&1
pkill -f "startlxqt"     > /dev/null 2>&1
pkill -f "mate-session"  > /dev/null 2>&1
pkill -f "openbox"       > /dev/null 2>&1
pkill -f "marco"         > /dev/null 2>&1
sleep 1

# Remove residual X11 locks
rm -f /tmp/.X1-lock         > /dev/null 2>&1
rm -f /tmp/.X11-unix/X1     > /dev/null 2>&1

# ---------------------------------------------------------------------------
# DETECT DESKTOP ENVIRONMENT
# ---------------------------------------------------------------------------
DESKTOP_SESSION="unknown"

# 1. Read from desktop.conf (high priority - written by install.sh / mate.sh / lxqt.sh)
if [ -f "$OHMYTERMUX_CONFIG/desktop.conf" ]; then
    source "$OHMYTERMUX_CONFIG/desktop.conf"
fi

# 2. Fallback: read from theme_config.tmp
if [ "$DESKTOP_SESSION" = "unknown" ] || [ -z "$DESKTOP_SESSION" ]; then
    if [ -f "$OHMYTERMUX_CONFIG/theme_config.tmp" ]; then
        DETECTED=$(grep '^DESKTOP_ENV=' "$OHMYTERMUX_CONFIG/theme_config.tmp" | cut -d'=' -f2 | tr -d '"')
        [ -n "$DETECTED" ] && DESKTOP_SESSION="$DETECTED"
    fi
fi

# 3. Final fallback: detect by binary presence
if [ "$DESKTOP_SESSION" = "unknown" ] || [ -z "$DESKTOP_SESSION" ]; then
    if command -v mate-session > /dev/null 2>&1; then
        DESKTOP_SESSION="mate"
    elif command -v startlxqt > /dev/null 2>&1 || command -v lxqt-session > /dev/null 2>&1; then
        DESKTOP_SESSION="lxqt"
    elif command -v xfce4-session > /dev/null 2>&1; then
        DESKTOP_SESSION="xfce"
    else
        echo "[start] No desktop environment detected (xfce4-session, startlxqt or mate-session)."
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
# START TERMUX-X11
# ---------------------------------------------------------------------------
XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :1.0 &> /dev/null &
sleep 1

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

# ---------------------------------------------------------------------------
# VIRGL (GPU rendering)
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
# START DESKTOP SESSION
# ---------------------------------------------------------------------------
export DISPLAY=:1.0
export GALLIUM_DRIVER=virpipe

case "$DESKTOP_SESSION" in
    mate)
        env DISPLAY=:1.0 GALLIUM_DRIVER=virpipe \
            dbus-launch --exit-with-session mate-session &> /dev/null &
        sleep 5
        process_id=$(ps -aux | grep '[x]screensaver' | awk '{print $2}')
        [ -n "$process_id" ] && kill "$process_id" > /dev/null 2>&1
        ;;
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
        echo "[start] Unknown desktop environment: $DESKTOP_SESSION"
        echo "        Accepted values: xfce, lxqt, mate"
        exit 1
        ;;
esac
STARTEOF

    chmod +x "$PREFIX/bin/start"

    # Update the stop script to handle XFCE, LXQt and MATE
    cat > "$PREFIX/bin/kill_termux_x11" << STOPEOF
#!/bin/bash

OHMYTERMUX_CONFIG="\$HOME/.config/OhMyTermux"
DESKTOP_SESSION="mate"
[ -f "\$OHMYTERMUX_CONFIG/desktop.conf" ] && source "\$OHMYTERMUX_CONFIG/desktop.conf"

if pgrep -f 'apt|apt-get|dpkg|nala' > /dev/null; then
    zenity --info --text="A software is being installed. Please wait before stopping the session."
    exit 1
fi

termux_x11_pid=\$(pgrep -f /system/bin/app_process.*com.termux.x11.Loader)
virgl_pid=\$(pgrep -f "virgl_test_server")

case "\$DESKTOP_SESSION" in
    mate)
        de_pid=\$(pgrep -f "mate-session")
        wm_pid=\$(pgrep -f "marco")
        de_name="MATE"
        ;;
    lxqt)
        de_pid=\$(pgrep -f "lxqt-session")
        wm_pid=\$(pgrep -f "openbox")
        de_name="LXQt"
        ;;
    *)
        de_pid=\$(pgrep -f "xfce4-session")
        wm_pid=""
        de_name="XFCE"
        ;;
esac

[ -n "\$termux_x11_pid" ] && kill -9 "\$termux_x11_pid" 2>/dev/null
[ -n "\$de_pid"          ] && kill -9 "\$de_pid"         2>/dev/null
[ -n "\$wm_pid"          ] && kill -9 "\$wm_pid"         2>/dev/null
[ -n "\$virgl_pid"       ] && kill -9 "\$virgl_pid"      2>/dev/null

rm -f /tmp/.X1-lock       2>/dev/null
rm -f /tmp/.X11-unix/X1   2>/dev/null

if [ -n "\$termux_x11_pid" ] || [ -n "\$de_pid" ]; then
    zenity --info --title="Session closed" \
        --text="Termux-X11 and \$de_name session closed." 2>/dev/null || true
else
    zenity --info --title="Session not found" \
        --text="Termux-X11 or \$de_name session not found." 2>/dev/null || true
fi
STOPEOF

    chmod +x "$PREFIX/bin/kill_termux_x11"
}

#------------------------------------------------------------------------------
# ENTRY POINT
#------------------------------------------------------------------------------
main
