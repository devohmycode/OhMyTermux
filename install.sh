#!/bin/bash

#------------------------------------------------------------------------------
# INTERNATIONALIZATION SYSTEM
#------------------------------------------------------------------------------
# Determine the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

        # Create the directory if needed
        mkdir -p "$LOCAL_DIR"

        # Download the file
        if ! curl -L -s -o "$LOCAL_PATH" "$URL" 2>/dev/null; then
            echo "Warning: Could not download $FILE from $URL" >&2
            return 1
        fi
    done

    return 0
}

# Load the internationalization library
if [ -f "$SCRIPT_DIR/i18n/i18n.sh" ]; then
    source "$SCRIPT_DIR/i18n/i18n.sh"
else
    echo "Initializing i18n system..." >&2
    # Temporarily set BRANCH if not already set
    if [ -z "$BRANCH" ]; then
        BRANCH="main"
    fi
    # Download the i18n system
    if download_i18n_system; then
        source "$SCRIPT_DIR/i18n/i18n.sh"
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
# GitHub branch for downloads
BRANCH="main"

# Interactive interface with gum
USE_GUM=false

# Initial configuration
EXECUTE_INITIAL_CONFIG=true

# Detailed output
VERBOSE=false

# Variables for Debian PRoot
PROOT_USERNAME=""
PROOT_PASSWORD=""

#------------------------------------------------------------------------------
# SELECTORS OF MODULES
#------------------------------------------------------------------------------
# Shell selection
SHELL_CHOICE=false

# Additional packages installation
PACKAGES_CHOICE=false

# Custom fonts installation
FONT_CHOICE=false

# XFCE environment installation
XFCE_CHOICE=false

# Debian Proot installation
PROOT_CHOICE=false

# Termux-X11 installation
X11_CHOICE=false

# Full installation without interactions
FULL_INSTALL=false

# Use gum for interactions
ONLY_GUM=true

#------------------------------------------------------------------------------
# CONFIGURATION FILES
#------------------------------------------------------------------------------
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"
FISHRC="$HOME/.config/fish/config.fish"

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
    REDIRECT="> /dev/null 2>&1"
else
    REDIRECT=""
fi

#------------------------------------------------------------------------------
# DISPLAY HELP
#------------------------------------------------------------------------------
show_help() {
    # Initialiser le système i18n si pas encore fait
    if [ "$MESSAGES_LOADED" != "true" ]; then
        init_i18n "$OVERRIDE_LANG" >/dev/null 2>&1
    fi
    
    clear
    echo "$(t MSG_HELP_TITLE)"
    echo 
    echo "$(t MSG_HELP_USAGE)"
    echo "$(t MSG_HELP_OPTIONS)"
    echo "  --gum | -g        $(t MSG_OPT_GUM)"
    echo "  --verbose | -v    $(t MSG_OPT_VERBOSE)"
    echo "  --lang | -l       $(t MSG_OPT_LANG)"
    echo "  --shell | -sh     $(t MSG_OPT_SHELL)"
    echo "  --package | -pk   $(t MSG_OPT_PACKAGE)"
    echo "  --font | -f       $(t MSG_OPT_FONT)"
    echo "  --xfce | -x       $(t MSG_OPT_XFCE)"
    echo "  --proot | -pr     $(t MSG_OPT_PROOT)"
    echo "  --x11             $(t MSG_OPT_X11)"
    echo "  --skip            $(t MSG_OPT_SKIP)"
    echo "  --uninstall       $(t MSG_OPT_UNINSTALL)"
    echo "  --full            $(t MSG_OPT_FULL)"
    echo "  --help | -h       $(t MSG_OPT_HELP)"
    echo
    echo "$(t MSG_HELP_EXAMPLES)"
    echo "  $(t MSG_EXAMPLE_GUM)"
    echo "  $(t MSG_EXAMPLE_FULL)"
}

#------------------------------------------------------------------------------
# ARGUMENTS MANAGEMENT
#------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --gum|-g)
            USE_GUM=true
            shift
            ;;
        --shell|-sh)
            SHELL_CHOICE=true
            ONLY_GUM=false
            shift
            ;;
        --package|-pk)
            PACKAGES_CHOICE=true
            ONLY_GUM=false
            shift
            ;;
        --font|-f)
            FONT_CHOICE=true
            ONLY_GUM=false
            shift
            ;;
        --xfce|-x)
            XFCE_CHOICE=true
            ONLY_GUM=false
            shift
            ;;
        --proot|-pr)
            PROOT_CHOICE=true
            ONLY_GUM=false
            shift
            ;;
        --x11)
            X11_CHOICE=true
            ONLY_GUM=false
            shift
            ;;
        --skip)
            EXECUTE_INITIAL_CONFIG=false
            shift
            ;;
        --uninstall)
            uninstall_proot
            exit 0
            ;;
        --verbose|-v)
            VERBOSE=true
            REDIRECT=""
            shift
            ;;
        --lang|-l)
            shift
            if [ -n "$1" ]; then
                OVERRIDE_LANG="$1"
                shift
            else
                echo "$(t MSG_ERROR_LANG_ARGUMENT)" >&2
                exit 1
            fi
            ;;
        --full)
            FULL_INSTALL=true
            SHELL_CHOICE=true
            PACKAGES_CHOICE=true
            FONT_CHOICE=true
            XFCE_CHOICE=true
            PROOT_CHOICE=true
            X11_CHOICE=true
            SCRIPT_CHOICE=true
            ONLY_GUM=false
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            # Get the username and password if provided
            if [ -z "$PROOT_USERNAME" ]; then
                PROOT_USERNAME="$1"
            elif [ -z "$PROOT_PASSWORD" ]; then
                PROOT_PASSWORD="$1"
            else
                break
            fi
            shift
            ;;
    esac
done

# If in FULL_INSTALL mode and identifiers are not provided, ask for them
if $FULL_INSTALL; then
    if [ -z "$PROOT_USERNAME" ]; then
        if $USE_GUM; then
            PROOT_USERNAME=$(gum input --placeholder "$(t MSG_INFO_ENTER_USERNAME_PROOT)")
        else
            printf "${COLOR_BLUE}$(t MSG_INFO_ENTER_USERNAME_PROOT) ${COLOR_RESET}"
            read -r PROOT_USERNAME
        fi
    fi
    
    if [ -z "$PROOT_PASSWORD" ]; then
        while true; do
            if $USE_GUM; then
                PROOT_PASSWORD=$(gum input --password --prompt "Password: " --placeholder "$(t MSG_INFO_PASSWORD)")
                PASSWORD_CONFIRM=$(gum input --password --prompt "Confirm password: " --placeholder "$(t MSG_INFO_CONFIRM_PASSWORD)")
            else
                printf "${COLOR_BLUE}$(t MSG_INFO_PASSWORD) ${COLOR_RESET}"
                read -r -s PROOT_PASSWORD
                echo
                printf "${COLOR_BLUE}$(t MSG_INFO_CONFIRM_PASSWORD) ${COLOR_RESET}"
                read -r -s PASSWORD_CONFIRM
                echo
            fi

            if [ "$PROOT_PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                if $USE_GUM; then
                    gum style --foreground 196 "$(t MSG_ERROR_PASSWORD_MISMATCH)"
                else
                    echo -e "${COLOR_RED}$(t MSG_ERROR_PASSWORD_MISMATCH)${COLOR_RESET}"
                fi
            fi
        done
    fi
fi

# Activate all modules if --gum is the only argument
if $ONLY_GUM; then
    SHELL_CHOICE=true
    PACKAGES_CHOICE=true
    FONT_CHOICE=true
    XFCE_CHOICE=true
    PROOT_CHOICE=true
    X11_CHOICE=true
    SCRIPT_CHOICE=true
fi

# Initialisation du système d'internationalisation
if ! init_i18n "$OVERRIDE_LANG"; then
    echo "Warning: Problem during i18n system initialization. Using default messages." >&2
fi

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
    echo "[$(date +'%d/%m/%Y %H:%M:%S')] ERREUR: $ERROR_MSG | Utilisateur: $USERNAME | Machine: $HOSTNAME | Répertoire: $CWD" >> "$HOME/.config/OhMyTermux/install.log"
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

    if $FULL_INSTALL; then
        if [ -n "$SELECTED" ]; then
            echo "$SELECTED"
        else
            # Return the first option by default
            echo "${OPTIONS[0]}"
        fi
    else
        gum choose --selected.foreground="33" --header.foreground="33" --cursor.foreground="33" --height="$HEIGHT" --header="$PROMPT" --selected="$SELECTED" "${OPTIONS[@]}"
    fi
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

    if $FULL_INSTALL; then
        if [ -n "$SELECTED" ]; then
            echo "$SELECTED"
        else
            echo "${OPTIONS[@]}"
        fi
    else
        gum choose --no-limit --selected.foreground="33" --header.foreground="33" --cursor.foreground="33" --height="$HEIGHT" --header="$PROMPT" --selected="$SELECTED" "${OPTIONS[@]}"
    fi
}

#------------------------------------------------------------------------------
# TEXT MODE BANNER
#------------------------------------------------------------------------------
bash_banner() {
    clear
    local BANNER="
╔════════════════════════════════════════╗
║                                        ║
║                OHMYTERMUX              ║
║                                        ║
╚════════════════════════════════════════╝"

    echo -e "${COLOR_BLUE}${BANNER}${COLOR_RESET}\n"
}

#------------------------------------------------------------------------------
# GUM INSTALLATION
#------------------------------------------------------------------------------
check_and_install_gum() {
    if $USE_GUM && ! command -v gum &> /dev/null; then
        bash_banner
        echo -e "${COLOR_BLUE}$(t MSG_INSTALL_GUM)${COLOR_RESET}"
        pkg update -y > /dev/null 2>&1 && pkg install gum -y > /dev/null 2>&1
    fi
}

check_and_install_gum

#------------------------------------------------------------------------------
# ERROR MANAGEMENT
#------------------------------------------------------------------------------
finish() {
    local RET=$?
    if [ ${RET} -ne 0 ] && [ ${RET} -ne 130 ]; then
        echo
        if $USE_GUM; then
            gum style --foreground 196 "$(t MSG_ERROR_INSTALL)"
        else
            echo -e "${COLOR_RED}$(t MSG_ERROR_INSTALL)${COLOR_RESET}"
        fi
        echo -e "${COLOR_BLUE}$(t MSG_ERROR_REFER_MESSAGES)${COLOR_RESET}"
    fi
}

trap finish EXIT

#------------------------------------------------------------------------------
# GRAPHIC BANNER
#------------------------------------------------------------------------------
show_banner() {
    # Initialiser le système i18n si pas encore fait
    if [ "$MESSAGES_LOADED" != "true" ]; then
        init_i18n "$OVERRIDE_LANG" >/dev/null 2>&1
    fi
    
    clear
    if $USE_GUM; then
        gum style \
            --foreground 33 \
            --border-foreground 33 \
            --border double \
            --align center \
            --width 42 \
            --margin "1 1 1 0" \
            "" "$(t MSG_BANNER_TITLE)" ""
    else
        bash_banner
    fi
}

#------------------------------------------------------------------------------
# FILE BACKUP
#------------------------------------------------------------------------------
create_backups() {
    local BACKUP_DIR="$HOME/.config/OhMyTermux/backups"
    
    # Create the backup directory
    execute_command "mkdir -p \"$BACKUP_DIR\"" "$(t MSG_PROGRESS_CREATE_BACKUP_DIR)"

    # List of files to backup
    local FILES_TO_BACKUP=(
        "$HOME/.bashrc"
        "$HOME/.termux/colors.properties"
        "$HOME/.termux/termux.properties"
        "$HOME/.termux/font.ttf"
        #"$0"
    )

    # Copy files to backup directory
    for FILE in "${FILES_TO_BACKUP[@]}"; do
        if [ -f "$FILE" ]; then
            execute_command "cp \"$FILE\" \"$BACKUP_DIR/\"" "$(t MSG_PROGRESS_BACKUP_FILE) $(basename "$FILE")"
        fi
    done
}

#------------------------------------------------------------------------------
# COMMON ALIAS CONFIGURATION
#------------------------------------------------------------------------------
common_alias() {
    # Create the centralized alias file
    if [ ! -d "$HOME/.config/OhMyTermux" ]; then
        execute_command "mkdir -p \"$HOME/.config/OhMyTermux\"" "$(t MSG_PROGRESS_CREATE_CONFIG_FOLDER)"
    fi

    ALIASES_FILE="$HOME/.config/OhMyTermux/aliases"

    cat > "$ALIASES_FILE" << 'EOL'
# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# Base commands
alias h="history"
alias q="exit"
alias c="clear"
alias md="mkdir"
alias rm="rm -rf"
alias s="source"
alias n="nano"
alias cm="chmod +x"

# Configuration
alias bashrc="nano $HOME/.bashrc"
alias zshrc="nano $HOME/.zshrc"
alias aliases="nano $HOME/.config/OhMyTermux/aliases"
alias help="cat $HOME/.config/OhMyTermux/help.md"

# Git
alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gb="git branch"
alias gco="git checkout"
alias gcl="git clone"
alias push="git pull && git add . && git commit -m 'mobile push' && git push"

# Termux
alias termux="termux-reload-settings"
alias storage="termux-setup-storage"
alias share="termux-share"
alias open="termux-open"
alias url="termux-open-url"
alias clip="termux-clipboard-set"
alias notification="termux-notification"
alias vibrate="termux-vibrate"
alias battery="termux-battery-status"
alias torch="termux-torch"
alias volume="termux-volume"
alias wifi="termux-wifi-connectioninfo"
alias tts="termux-tts-speak"
alias call="termux-telephony-call"
alias contact="termux-contact-list"
alias sms="termux-sms-send"
alias location="termux-location"

EOL

    # Add the sourcing .bashrc
    echo -e "\n# Source of custom aliases\n[ -f \"$ALIASES_FILE\" ] && . \"$ALIASES_FILE\"" >> "$BASHRC"
    # The sourcing .zshrc is done in update_zshrc()
}

#------------------------------------------------------------------------------
# DOWNLOAD AND EXECUTE FUNCTION
#------------------------------------------------------------------------------
download_and_execute() {
    local URL="$1"
    local SCRIPT_NAME=$(basename "$URL")
    local DESCRIPTION="${2:-$SCRIPT_NAME}"
    shift 2
    local EXEC_ARGS="$@"

    # Check if the file already exists and delete it
    [ -f "$SCRIPT_NAME" ] && rm "$SCRIPT_NAME"

    # Download with curl in silent mode but with progress bar
    #if ! curl -L --progress-bar -o "$SCRIPT_NAME" "$URL"; then
    if ! curl -L -o "$SCRIPT_NAME" "$URL" 2>/dev/null; then
        error_msg "$(t MSG_ERROR_DOWNLOAD_SCRIPT) $DESCRIPTION"
        return 1
    fi

    # Check if the file has been downloaded
    if [ ! -f "$SCRIPT_NAME" ]; then
        error_msg "$(t MSG_ERROR_FILE_NOT_CREATED_GENERIC) $SCRIPT_NAME"
        return 1
    fi

    # Make the script executable
    if ! chmod +x "$SCRIPT_NAME"; then
        error_msg "$(t MSG_ERROR_MAKE_EXECUTABLE) $DESCRIPTION"
        return 1
    fi

    # Execute the script with the arguments, passing --lang if set
    local LANG_ARG=""
    if [ -n "$OVERRIDE_LANG" ]; then
        LANG_ARG="--lang $OVERRIDE_LANG"
    fi

    if ! ./"$SCRIPT_NAME" $LANG_ARG $EXEC_ARGS; then
        error_msg "$(t MSG_ERROR_SCRIPT_EXECUTION) $DESCRIPTION"
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# REPOSITORY CHANGE
#------------------------------------------------------------------------------
change_repo() {
    show_banner
    if $USE_GUM; then
        if gum_confirm "$(t MSG_CONFIRM_CHANGE_REPO)"; then
            termux-change-repo
        fi
    else    
        printf "${COLOR_BLUE}$(t MSG_CONFIRM_CHANGE_REPO) (O/n) : ${COLOR_RESET}"
        read -r -e -p "" -i "o" CHOICE
        [[ "$CHOICE" =~ ^[oO]$ ]] && termux-change-repo
    fi
}

#------------------------------------------------------------------------------
# STORAGE CONFIGURATION
#------------------------------------------------------------------------------
setup_storage() {
    if [ ! -d "$HOME/storage" ]; then
        show_banner
        if $USE_GUM; then
            if gum_confirm "$(t MSG_CONFIRM_ALLOW_STORAGE)"; then
                termux-setup-storage
            fi
        else
            printf "${COLOR_BLUE}$(t MSG_CONFIRM_ALLOW_STORAGE) (O/n) : ${COLOR_RESET}"
            read -r -e -p "" -i "n" CHOICE
            [[ "$CHOICE" =~ ^[oO]$ ]] && termux-setup-storage
        fi
    fi
}

#------------------------------------------------------------------------------
# TERMUX CONFIGURATION
#------------------------------------------------------------------------------
configure_termux() {
    title_msg "$(t MSG_CONFIG_TERMUX)"
    # Backup existing files
    create_backups
    TERMUX_DIR="$HOME/.termux"
    
    # Colors.properties configuration
    FILE_PATH="$TERMUX_DIR/colors.properties"
    if [ ! -f "$FILE_PATH" ]; then
        mkdir -p "$TERMUX_DIR"
        cat > "$FILE_PATH" << 'EOL'
# https://github.com/Mayccoll/Gogh/blob/master/themes/argonaut.sh
background=#0e1019
foreground=#fffaf4
cursor=#fffaf4
color0=#232323
color1=#ff000f
color2=#8ce10b
color3=#ffb900
color4=#008df8
color5=#6d43a6
color6=#00d8eb
color7=#ffffff
color8=#444444
color9=#ff2740
color10=#abe15b
color11=#ffd242
color12=#0092ff
color13=#9a5feb
color14=#67fff0
color15=#ffffff
EOL
        success_msg "✓ Argonaut theme installed"
    fi

    # Common alias configuration
    common_alias
    
    # Termux.properties configuration
    FILE_PATH="$TERMUX_DIR/termux.properties"
    if [ ! -f "$FILE_PATH" ]; then
        execute_command "cat > \"$FILE_PATH\" << 'EOL'
allow-external-apps = true
use-black-ui = true
bell-character = ignore
fullscreen = true
EOL" "$(t MSG_PROGRESS_TERMUX_PROPERTIES_CONFIG)"
    else
        execute_command "sed -i 's/^# allow-external-apps = true/allow-external-apps = true/' \"$FILE_PATH\" && \
        sed -i 's/^# use-black-ui = true/use-black-ui = true/' \"$FILE_PATH\" && \
        sed -i 's/^# bell-character = ignore/bell-character = ignore/' \"$FILE_PATH\" && \
        sed -i 's/^# fullscreen = true/fullscreen = true/' \"$FILE_PATH\"" "$(t MSG_CONFIG_TERMUX_PROPS)"
    fi
    # Suppression of the login banner
    execute_command "touch $HOME/.hushlogin" "$(t MSG_PROGRESS_SUPPRESS_LOGIN_BANNER)"
}

#------------------------------------------------------------------------------
# INITIAL CONFIGURATION
#------------------------------------------------------------------------------
initial_config() {
    # Si on est en mode FULL_INSTALL, demander les identifiants au début
    if $FULL_INSTALL; then
        title_msg "$(t MSG_CONFIG_PROOT)"
        if [ -z "$PROOT_USERNAME" ]; then
            if $USE_GUM; then
                PROOT_USERNAME=$(gum input --placeholder "$(t MSG_INFO_ENTER_USERNAME_PROOT)")
                PROOT_PASSWORD=$(gum input --password --placeholder "$(t MSG_INFO_ENTER_PASSWORD_PROOT)")
            else
                printf "${COLOR_BLUE}$(t MSG_INFO_ENTER_USERNAME_PROOT) ${COLOR_RESET}"
                read -r PROOT_USERNAME
                printf "${COLOR_BLUE}$(t MSG_INFO_ENTER_PASSWORD_PROOT) ${COLOR_RESET}"
                read -r -s PROOT_PASSWORD
                echo
            fi
        fi
    fi

    change_repo

    # Update and upgrade packages preserving existing configurations
    clear
    show_banner
    execute_command "pkg update -y -o Dpkg::Options::=\"--force-confold\"" "$(t MSG_PROGRESS_UPDATE_REPOS)"
    execute_command "pkg upgrade -y -o Dpkg::Options::=\"--force-confold\"" "$(t MSG_PROGRESS_UPGRADE_PACKAGES)"

    setup_storage

    if $USE_GUM; then
        show_banner
        if gum_confirm "$(t MSG_CONFIRM_ACTIVATE_CONFIG)"; then
            configure_termux
        fi
    else
        show_banner
        printf "${COLOR_BLUE}$(t MSG_CONFIRM_ACTIVATE_CONFIG) (O/n) : ${COLOR_RESET}"
        read -r -e -p "" -i "o" CHOICE
        # Clear the previous line
        tput cuu1  # Move up one line
        tput el    # Clear to the end of the line
        [[ "$CHOICE" =~ ^[oO]$ ]] && configure_termux
    fi
}

#------------------------------------------------------------------------------
# INSTALLATION OF THE SHELL
#------------------------------------------------------------------------------
install_shell() {
    if $SHELL_CHOICE; then
        title_msg "$(t MSG_SHELL_CONFIG_TITLE)"
        if $USE_GUM; then
            SHELL_CHOICE=$(gum_choose "$(t MSG_CHOOSE_SHELL_PROMPT)" --selected="zsh" --height=5 "bash" "zsh" "fish")
        else
            echo -e "${COLOR_BLUE}$(t MSG_CHOOSE_SHELL_PROMPT)${COLOR_RESET}"
            echo
            echo -e "${COLOR_BLUE}$(t MSG_BASH_OPTION)${COLOR_RESET}"
            echo -e "${COLOR_BLUE}$(t MSG_ZSH_OPTION)${COLOR_RESET}"
            echo -e "${COLOR_BLUE}$(t MSG_FISH_OPTION)${COLOR_RESET}"
            echo
            printf "${COLOR_GOLD}$(t MSG_ENTER_SHELL_CHOICE) ${COLOR_RESET}"
            tput setaf 3
            read -r -e -p "" -i "2" CHOICE
            tput sgr0

            # Clear the selection menu
            tput cuu 7  # Move up 7 lines
            tput ed     # Clear to the end of the screen

            case $CHOICE in
                1) SHELL_CHOICE="bash" ;;
                2) SHELL_CHOICE="zsh" ;;
                3) SHELL_CHOICE="fish" ;;
                *) SHELL_CHOICE="bash" ;;
            esac
        fi

        case $SHELL_CHOICE in
            "bash")
                success_msg "$(t MSG_BASH_SELECTED)"
                install_prompt
                ;;
            "zsh")
                if ! command -v zsh &> /dev/null; then
                    execute_command "pkg install -y zsh" "$(t MSG_INSTALL_ZSH)"
                else
                    success_msg "$(t MSG_ZSH_ALREADY_INSTALLED)"
                fi
                # Installation de Oh My Zsh et autres configurations ZSH
                title_msg "$(t MSG_ZSH_CONFIG_TITLE)"
                if [ ! -d "$HOME/.oh-my-zsh" ]; then
                    if $USE_GUM; then
                        if gum_confirm "$(t MSG_CONFIRM_INSTALL_OHMYZSH)"; then
                            execute_command "pkg install -y wget curl git unzip" "$(t MSG_INSTALL_DEPENDENCIES)"
                            execute_command "git clone https://github.com/ohmyzsh/ohmyzsh.git \"$HOME/.oh-my-zsh\"" "$(t MSG_INSTALL_OHMYZSH_PROGRESS)"
                            cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
                        fi
                    else
                        printf "${COLOR_BLUE}$(t MSG_CONFIRM_INSTALL_OHMYZSH) (O/n) : ${COLOR_RESET}"
                        read -r -e -p "" -i "o" CHOICE
                        tput cuu1
                        tput el
                        if [[ "$CHOICE" =~ ^[oO]$ ]]; then
                            execute_command "pkg install -y wget curl git unzip" "$(t MSG_INSTALL_DEPENDENCIES)"
                            execute_command "git clone https://github.com/ohmyzsh/ohmyzsh.git \"$HOME/.oh-my-zsh\"" "$(t MSG_INSTALL_OHMYZSH_PROGRESS)"
                            cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
                        fi
                    fi
                else
                    success_msg "$(t MSG_OHMYZSH_ALREADY_INSTALLED)"
                fi

                execute_command "curl -fLo \"$ZSHRC\" https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/src/zshrc" "$(t MSG_DEFAULT_CONFIG_PROGRESS)" || error_msg "$(t MSG_ERROR_DEFAULT_CONFIG)"

                if command -v zsh &> /dev/null; then
                    install_zsh_plugins
                    install_prompt
                else
                    echo -e "${COLOR_RED}$(t MSG_ZSH_NOT_INSTALLED_ERROR)${COLOR_RESET}"
                fi
                chsh -s zsh
                ;;
            "fish")
                title_msg "$(t MSG_FISH_CONFIG_TITLE)"
                execute_command "pkg install -y fish" "$(t MSG_FISH_INSTALLATION)"
                execute_command "mkdir -p $HOME/.config/fish/functions" "$(t MSG_CREATE_FISH_DIR)"
                # Installation of Fisher in non-interactive mode
                execute_command "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish -o $HOME/.config/fish/functions/fisher.fish" "$(t MSG_DOWNLOAD_FISHER)"
                # Installation of Tide via Fisher in non-interactive mode
                execute_command "fish -c 'source $HOME/.config/fish/functions/fisher.fish && fisher install IlanCosman/tide@v5'" "$(t MSG_TIDE_INSTALLATION)"
                chsh -s fish
                ;;
        esac
    fi
}

#------------------------------------------------------------------------------
# INSTALLATION OF THE PROMPT
#------------------------------------------------------------------------------
install_prompt() {
    local PROMPT_CHOICE
    local CURRENT_SHELL="${SHELL_CHOICE:-zsh}"
    
    if [ "$CURRENT_SHELL" = "bash" ]; then
        if $USE_GUM; then
            PROMPT_CHOICE=$(gum_choose "$(t MSG_CHOOSE_PROMPT_BASH)" --height=4 --selected="Oh-My-Posh" "Oh-My-Posh" "Starship")
        else
            echo -e "${COLOR_BLUE}$(t MSG_CHOOSE_PROMPT_BASH)${COLOR_RESET}"
            echo
            echo -e "${COLOR_BLUE}$(t MSG_OHMYPOSH_OPTION_BASH)${COLOR_RESET}"
            echo -e "${COLOR_BLUE}$(t MSG_STARSHIP_OPTION_BASH)${COLOR_RESET}"
            echo
            printf "${COLOR_GOLD}$(t MSG_ENTER_PROMPT_CHOICE_BASH) ${COLOR_RESET}"
            tput setaf 3
            read -r -e -p "" -i "1" CHOICE
            tput sgr0
            tput cuu 5
            tput ed
            
            case $CHOICE in
                1) PROMPT_CHOICE="Oh-My-Posh" ;;
                2) PROMPT_CHOICE="Starship" ;;
                *) PROMPT_CHOICE="Oh-My-Posh" ;;
            esac
        fi
    else
        if $USE_GUM; then
            PROMPT_CHOICE=$(gum_choose "$(t MSG_CHOOSE_PROMPT)" --height=5 --selected="PowerLevel10k" "PowerLevel10k" "Oh-My-Posh" "Starship")
        else
            echo -e "${COLOR_BLUE}$(t MSG_CHOOSE_PROMPT)${COLOR_RESET}"
            echo
            echo -e "${COLOR_BLUE}$(t MSG_POWERLEVEL10K_OPTION)${COLOR_RESET}"
            echo -e "${COLOR_BLUE}$(t MSG_OHMYPOSH_OPTION)${COLOR_RESET}"
            echo -e "${COLOR_BLUE}$(t MSG_STARSHIP_OPTION)${COLOR_RESET}"
            echo
            printf "${COLOR_GOLD}$(t MSG_ENTER_PROMPT_CHOICE) ${COLOR_RESET}"
            tput setaf 3
            read -r -e -p "" -i "1" CHOICE
            tput sgr0
            tput cuu 7
            tput ed
            
            case $CHOICE in
                1) PROMPT_CHOICE="PowerLevel10k" ;;
                2) PROMPT_CHOICE="Oh-My-Posh" ;;
                3) PROMPT_CHOICE="Starship" ;;
                *) PROMPT_CHOICE="PowerLevel10k" ;;
            esac
        fi
    fi

    case $PROMPT_CHOICE in
        "PowerLevel10k")
            if $USE_GUM; then
                if gum_confirm "$(t MSG_CONFIRM_POWERLEVEL10K)"; then
                    execute_command "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \"$HOME/.oh-my-zsh/custom/themes/powerlevel10k\" || true" "$(t MSG_INSTALL_POWERLEVEL10K_PROGRESS)"
                    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC"

                    if gum_confirm "$(t MSG_CONFIRM_INSTALL_CUSTOM_PROMPT)"; then
                        execute_command "curl -fLo \"$HOME/.p10k.zsh\" https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/src/p10k.zsh" "$(t MSG_INSTALL_CUSTOM_PROMPT)" || error_msg "$(t MSG_ERROR_CUSTOM_PROMPT)"
                        echo -e "\n$(t MSG_CUSTOM_PROMPT_COMMENT)" >> "$ZSHRC"
                        echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> "$ZSHRC"
                    else
                        echo -e "${COLOR_BLUE}$(t MSG_CUSTOMIZE_P10K_INFO)${COLOR_RESET}"
                    fi
                fi
            else
                printf "${COLOR_BLUE}$(t MSG_CONFIRM_POWERLEVEL10K) (O/n) : ${COLOR_RESET}"
                read -r -e -p "" -i "o" CHOICE
                tput cuu1
                tput el
                if [[ "$CHOICE" =~ ^[oO]$ ]]; then
                    execute_command "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \"$HOME/.oh-my-zsh/custom/themes/powerlevel10k\" > /dev/null 2>&1 || true" "$(t MSG_INSTALL_POWERLEVEL10K_PROGRESS)"
                    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC"

                    printf "${COLOR_BLUE}$(t MSG_CONFIRM_INSTALL_CUSTOM_PROMPT) (O/n) : ${COLOR_RESET}"
                    read -r -e -p "" -i "o" CHOICE
                    tput cuu1
                    tput el
                    if [[ "$CHOICE" =~ ^[oO]$ ]]; then
                        execute_command "curl -fLo \"$HOME/.p10k.zsh\" https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/src/p10k.zsh" "$(t MSG_INSTALL_CUSTOM_PROMPT)" || error_msg "$(t MSG_ERROR_CUSTOM_PROMPT)"
                        echo -e "\n$(t MSG_CUSTOM_PROMPT_COMMENT)" >> "$ZSHRC"
                        echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> "$ZSHRC"
                    else
                        echo -e "${COLOR_BLUE}$(t MSG_CUSTOMIZE_P10K_INFO)${COLOR_RESET}"
                    fi
                fi
            fi
            ;;
            
        "Oh-My-Posh")
            execute_command "pkg install -y oh-my-posh" "$(t MSG_INSTALL_OHMYPOSH_PROGRESS)"

            # Optional installation of a Nerd font
            if [ ! -f "$HOME/.termux/font.ttf" ]; then
                execute_command "curl -fLo \"$HOME/.termux/font.ttf\" --create-dirs https://raw.githubusercontent.com/termux/termux-styling/master/app/src/main/assets/fonts/DejaVu-Sans-Mono.ttf" "$(t MSG_INSTALL_NERD_FONT)"
            fi
            
            # Retrieving the complete list of themes
            THEMES_DIR="/data/data/com.termux/files/usr/share/oh-my-posh/themes"
            if [ -d "$THEMES_DIR" ]; then
                # Creating an array with all available themes
                mapfile -t AVAILABLE_THEMES < <(find "$THEMES_DIR" -name "*.omp.json" -exec basename {} .omp.json \; | sort)
            else
                error_msg "Oh-My-Posh themes directory not found"
                return 1
            fi

            # Theme selection
            if $USE_GUM; then
                THEME=$(printf '%s\n' "${AVAILABLE_THEMES[@]}" | gum_choose \
                    "$(t MSG_CHOOSE_OHMYPOSH_THEME)" \
                    --height=25)
            else
                # Displaying the numbered list of themes
                echo -e "${COLOR_BLUE}$(t MSG_CHOOSE_OHMYPOSH_THEME)${COLOR_RESET}"
                echo
                for i in "${!AVAILABLE_THEMES[@]}"; do
                    # Formatting the number for alignment (3 characters)
                    NUM=$(printf "%3d" $((i+1)))
                    if [ "${AVAILABLE_THEMES[$i]}" = "jandedobbeleer" ]; then
                        echo -e "${COLOR_BLUE}${NUM}) ${AVAILABLE_THEMES[$i]} $(t MSG_DEFAULT_THEME)${COLOR_RESET}"
                    else
                        echo -e "${COLOR_BLUE}${NUM}) ${AVAILABLE_THEMES[$i]}${COLOR_RESET}"
                    fi
                done
                echo
                # Calculating the number of lines to clear (number of themes + 3 lines for additional text)
                LINES_TO_CLEAR=$((${#AVAILABLE_THEMES[@]}+3))
                printf "${COLOR_GOLD}$(t MSG_ENTER_CHOICE_123) ${COLOR_RESET}"
                tput setaf 3
                read -r -e -p "" -i "1" CHOICE
                tput sgr0
                # Clearing the menu
                tput cuu $LINES_TO_CLEAR
                tput ed

                # Validating the choice
                if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#AVAILABLE_THEMES[@]}" ]; then
                    THEME="${AVAILABLE_THEMES[$((CHOICE-1))]}"
                else
                    THEME="jandedobbeleer"
                fi
            fi

            # Configuration for ZSH
            if [ ! -f "$ZSHRC" ]; then
                touch "$ZSHRC"
            fi
            sed -i '/# Initialize oh-my-posh/d' "$ZSHRC"
            sed -i '/eval "$(oh-my-posh init/d' "$ZSHRC"
            cat >> "$ZSHRC" << EOF

# Initialize oh-my-posh
eval "\$(oh-my-posh init zsh --config /data/data/com.termux/files/usr/share/oh-my-posh/themes/${THEME}.omp.json)"
EOF

            # Configuration for Bash
            if [ ! -f "$HOME/.bashrc" ]; then
                touch "$HOME/.bashrc"
            fi
            sed -i '/# Initialize oh-my-posh/d' "$HOME/.bashrc"
            sed -i '/eval "$(oh-my-posh init/d' "$HOME/.bashrc"
            cat >> "$HOME/.bashrc" << EOF

# Initialize oh-my-posh
eval "\$(oh-my-posh init bash --config /data/data/com.termux/files/usr/share/oh-my-posh/themes/${THEME}.omp.json)"
EOF
            ;;
        "Starship")
            execute_command "pkg install -y starship" "$(t MSG_INSTALL_STARSHIP_PROGRESS)"
            
            # Optional installation of a Nerd font
            if [ ! -f "$HOME/.termux/font.ttf" ]; then
                execute_command "curl -fLo \"$HOME/.termux/font.ttf\" --create-dirs https://raw.githubusercontent.com/termux/termux-styling/master/app/src/main/assets/fonts/DejaVu-Sans-Mono.ttf" "$(t MSG_INSTALL_NERD_FONT)"
            fi

            # Creating the configuration directory if it doesn't exist
            mkdir -p "$HOME/.config"

            # Preset selection
            if $USE_GUM; then
                PRESET=$(gum_choose "$(t MSG_CHOOSE_STARSHIP_PRESET)" --height=15 --selected="$(t PRESET_CUSTOM)" \
                    "$(t PRESET_CUSTOM)" \
                    "$(t PRESET_NERD_FONT_SYMBOLS)" \
                    "$(t PRESET_BRACKETED_SEGMENTS)" \
                    "$(t PRESET_NO_EMPTY_ICONS)" \
                    "$(t PRESET_NO_RUNTIME_VERSIONS)" \
                    "$(t PRESET_PLAIN_TEXT_SYMBOLS)" \
                    "$(t PRESET_PASTEL_POWERLINE)" \
                    "$(t PRESET_TOKYO_NIGHT)" \
                    "$(t PRESET_PURE_PRESET)" \
                    "$(t PRESET_GRUVBOX_RAINBOW)" \
                    "$(t PRESET_JETPACK)" \
                    "$(t PRESET_NO_NERD_FONT)" \
                    "$(t PRESET_RICE)" \
                    "$(t PRESET_SOLARIZED)")
            else
                echo -e "${COLOR_BLUE}$(t MSG_CHOOSE_STARSHIP_PRESET)${COLOR_RESET}"
                echo
                echo -e "${COLOR_BLUE}1)  $(t PRESET_CUSTOM)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}2)  $(t PRESET_NERD_FONT_SYMBOLS)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}3)  $(t PRESET_BRACKETED_SEGMENTS)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}4)  $(t PRESET_NO_EMPTY_ICONS)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}5)  $(t PRESET_NO_RUNTIME_VERSIONS)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}6)  $(t PRESET_PLAIN_TEXT_SYMBOLS)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}7)  $(t PRESET_PASTEL_POWERLINE)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}8)  $(t PRESET_TOKYO_NIGHT)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}9)  $(t PRESET_PURE_PRESET)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}10) $(t PRESET_GRUVBOX_RAINBOW)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}11) $(t PRESET_JETPACK)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}12) $(t PRESET_NO_NERD_FONT)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}13) $(t PRESET_RICE)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}14) $(t PRESET_SOLARIZED)${COLOR_RESET}"
                echo
                printf "${COLOR_GOLD}$(t MSG_ENTER_CHOICE_123) ${COLOR_RESET}"
                tput setaf 3
                read -r -e -p "" -i "1" CHOICE
                tput sgr0
                tput cuu 18
                tput ed
                
                case $CHOICE in
                    1) PRESET="$(t PRESET_CUSTOM)" ;;
                    2) PRESET="$(t PRESET_NERD_FONT_SYMBOLS)" ;;
                    3) PRESET="$(t PRESET_BRACKETED_SEGMENTS)" ;;
                    4) PRESET="$(t PRESET_NO_EMPTY_ICONS)" ;;
                    5) PRESET="$(t PRESET_NO_RUNTIME_VERSIONS)" ;;
                    6) PRESET="$(t PRESET_PLAIN_TEXT_SYMBOLS)" ;;
                    7) PRESET="$(t PRESET_PASTEL_POWERLINE)" ;;
                    8) PRESET="$(t PRESET_TOKYO_NIGHT)" ;;
                    9) PRESET="$(t PRESET_PURE_PRESET)" ;;
                    10) PRESET="$(t PRESET_GRUVBOX_RAINBOW)" ;;
                    11) PRESET="$(t PRESET_JETPACK)" ;;
                    12) PRESET="$(t PRESET_NO_NERD_FONT)" ;;
                    13) PRESET="$(t PRESET_RICE)" ;;
                    14) PRESET="$(t PRESET_SOLARIZED)" ;;
                    *) PRESET="$(t PRESET_CUSTOM)" ;;
                esac
            fi

            case $PRESET in
                "$(t PRESET_NERD_FONT_SYMBOLS)")
                    starship preset nerd-font-symbols -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_BRACKETED_SEGMENTS)") 
                    starship preset bracketed-segments -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_NO_EMPTY_ICONS)")
                    starship preset no-empty-icons -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_NO_RUNTIME_VERSIONS)")
                    starship preset no-runtime-versions -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_PLAIN_TEXT_SYMBOLS)")
                    starship preset plain-text-symbols -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_PASTEL_POWERLINE)")
                    starship preset pastel-powerline -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_TOKYO_NIGHT)")
                    starship preset tokyo-night -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_PURE_PRESET)")
                    starship preset pure -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_GRUVBOX_RAINBOW)")
                    starship preset gruvbox-rainbow -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_JETPACK)")
                    starship preset jetpack -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_NO_NERD_FONT)")
                    starship preset no-nerd-font -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_RICE)")
                    starship preset rice -o "$HOME/.config/starship.toml"
                    ;;
                "$(t PRESET_SOLARIZED)")
                    starship preset solarized -o "$HOME/.config/starship.toml"
                    ;;
                *)
                    # Default custom configuration
                    cat > "$HOME/.config/starship.toml" << 'EOF'
# Get help on configuration: https://starship.rs/config/
format = """$username$hostname$directory$git_branch$git_status$cmd_duration$line_break$character"""

# Disable default new line
add_newline = false

[directory]
style = "blue bold"
truncation_length = 3
truncate_to_repo = true

[character]
success_symbol = "[❯](purple bold)"
error_symbol = "[❯](red bold)"
vimcmd_symbol = "[❮](green bold)"

[git_branch]
format = "[$branch]($style)"
style = "bright-black"

[git_status]
format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)"
style = "cyan"
conflicted = "​"
untracked = "​"
modified = "​"
staged = "​"
renamed = "​"
deleted = "​"
stashed = "≡"

[git_state]
format = '\([$state( $progress_current/$progress_total)]($style)\) '
style = "bright-black"

[cmd_duration]
format = "[$duration]($style) "
style = "yellow"

[python]
format = "[$virtualenv]($style) "
style = "bright-black"

[username]
style_user = "white bold"
style_root = "black bold"
format = "[$user]($style) "
disabled = false
show_always = true

[hostname]
ssh_only = false
format = "on [$hostname](bold red) "
disabled = false
EOF
                    ;;
            esac

            # ZSH configuration
            if [ ! -f "$ZSHRC" ]; then
                touch "$ZSHRC"
            fi
            sed -i '/# Initialize Starship/d' "$ZSHRC"
            sed -i '/eval "$(starship init/d' "$ZSHRC"
            echo -e "\n# Initialize Starship\neval \"\$(starship init zsh)\"" >> "$ZSHRC"

            # Bash configuration
            if [ ! -f "$HOME/.bashrc" ]; then
                touch "$HOME/.bashrc"
            fi
            sed -i '/# Initialize Starship/d' "$HOME/.bashrc"
            sed -i '/eval "$(starship init/d' "$HOME/.bashrc"
            echo -e "\n# Initialize Starship\neval \"\$(starship init bash)\"" >> "$HOME/.bashrc"
            ;;
    esac
}

#------------------------------------------------------------------------------
# ZSH PLUGINS SELECTION
#------------------------------------------------------------------------------
install_zsh_plugins() {
    local PLUGINS_TO_INSTALL=()

    subtitle_msg "$(t MSG_PLUGINS_SUBTITLE)"

    if $USE_GUM; then
        mapfile -t PLUGINS_TO_INSTALL < <(gum_choose_multi "$(t MSG_SELECT_PLUGINS_GUM)" --height=8 --selected="$(t MSG_PLUGIN_ALL)" "zsh-autosuggestions" "zsh-syntax-highlighting" "zsh-completions" "you-should-use" "zsh-alias-finder" "$(t MSG_PLUGIN_ALL)")
        if [[ " ${PLUGINS_TO_INSTALL[*]} " == *" $(t MSG_PLUGIN_ALL) "* ]]; then
            PLUGINS_TO_INSTALL=("zsh-autosuggestions" "zsh-syntax-highlighting" "zsh-completions" "you-should-use" "zsh-alias-finder")
        fi
    else
        echo "$(t MSG_SELECT_PLUGINS_TEXT)"
        echo
        info_msg "$(t MSG_PLUGIN_1)"
        info_msg "$(t MSG_PLUGIN_2)"
        info_msg "$(t MSG_PLUGIN_3)"
        info_msg "$(t MSG_PLUGIN_4)"
        info_msg "$(t MSG_PLUGIN_5)"
        info_msg "$(t MSG_PLUGIN_6)"
        echo
        printf "${COLOR_GOLD}$(t MSG_ENTER_PLUGIN_NUMBERS_INPUT) ${COLOR_RESET}"
        tput setaf 3
        read -r -e -p "" -i "6" PLUGIN_CHOICES
        tput sgr0
        tput cuu 10
        tput ed
        for CHOICE in $PLUGIN_CHOICES; do
            case $CHOICE in
                1) PLUGINS_TO_INSTALL+=("zsh-autosuggestions") ;;
                2) PLUGINS_TO_INSTALL+=("zsh-syntax-highlighting") ;;
                3) PLUGINS_TO_INSTALL+=("zsh-completions") ;;
                4) PLUGINS_TO_INSTALL+=("you-should-use") ;;
                5) PLUGINS_TO_INSTALL+=("zsh-alias-finder") ;;
                6) PLUGINS_TO_INSTALL=("zsh-autosuggestions" "zsh-syntax-highlighting" "zsh-completions" "you-should-use" "zsh-alias-finder")
                break
                ;;
            esac
        done
    fi

    for PLUGIN in "${PLUGINS_TO_INSTALL[@]}"; do
        install_plugin "$PLUGIN"
    done

    # Define necessary variables
    local ZSHRC="$HOME/.zshrc"
    local SELECTED_PLUGINS="${PLUGINS_TO_INSTALL[*]}"
    local HAS_COMPLETIONS=false
    local HAS_OHMYTERMIX=true

    # Check if zsh-completions is installed
    if [[ " ${PLUGINS_TO_INSTALL[*]} " == *" zsh-completions "* ]]; then
        HAS_COMPLETIONS=true
    fi

    update_zshrc "$ZSHRC" "$SELECTED_PLUGINS" "$HAS_COMPLETIONS" "$HAS_OHMYTERMIX"
}

#------------------------------------------------------------------------------
# INSTALLATION OF ZSH PLUGINS
#------------------------------------------------------------------------------
install_plugin() {
    local PLUGIN_NAME=$1
    local PLUGIN_URL=""

    case $PLUGIN_NAME in
        "zsh-autosuggestions") PLUGIN_URL="https://github.com/zsh-users/zsh-autosuggestions.git" ;;
        "zsh-syntax-highlighting") PLUGIN_URL="https://github.com/zsh-users/zsh-syntax-highlighting.git" ;;
        "zsh-completions") PLUGIN_URL="https://github.com/zsh-users/zsh-completions.git" ;;
        "you-should-use") PLUGIN_URL="https://github.com/MichaelAquilina/zsh-you-should-use.git" ;;
        "zsh-alias-finder") PLUGIN_URL="https://github.com/akash329d/zsh-alias-finder.git" ;;
    esac

    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/$PLUGIN_NAME" ]; then
        execute_command "git clone '$PLUGIN_URL' '$HOME/.oh-my-zsh/custom/plugins/$PLUGIN_NAME' --quiet" "$(t MSG_PLUGIN_INSTALLATION_OF) $PLUGIN_NAME"
    else
        info_msg "  $PLUGIN_NAME $(t MSG_PLUGIN_ALREADY_INSTALLED)"
    fi
}

#------------------------------------------------------------------------------
# UPDATE OF ZSH CONFIGURATION
#------------------------------------------------------------------------------
update_zshrc() {
    local ZSHRC="$1"
    local SELECTED_PLUGINS="$2"
    local HAS_COMPLETIONS="$3"

    # Delete existing configuration
    sed -i '/fpath.*zsh-completions\/src/d' "$ZSHRC"
    sed -i '/source \$ZSH\/oh-my-zsh.sh/d' "$ZSHRC"
    sed -i '/# Source defined aliases/d' "$ZSHRC"
    sed -i '/\[ -f.*aliases.*/d' "$ZSHRC"

    # Création du contenu de la section plugins
    local DEFAULT_PLUGINS="git command-not-found copyfile node npm timer vscode web-search z"
    local FILTERED_PLUGINS=$(echo "$SELECTED_PLUGINS" | sed 's/zsh-completions//g')
    local ALL_PLUGINS="$DEFAULT_PLUGINS $FILTERED_PLUGINS"

    local PLUGINS_SECTION="plugins=(\n"
    for PLUGIN in $ALL_PLUGINS; do
        PLUGINS_SECTION+="    $PLUGIN\n"
    done
    PLUGINS_SECTION+=")\n"

    # Delete and replace the plugins section
    sed -i '/^plugins=(/,/)/d' "$ZSHRC"
    echo -e "$PLUGINS_SECTION" >> "$ZSHRC"

    # Add configuration by section
    if [ "$HAS_COMPLETIONS" = "true" ]; then
        echo -e "\n# Initialize zsh-completions\nfpath+=\${ZSH_CUSTOM:-\${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src" >> "$ZSHRC"
    fi

    echo -e "\n# Initialize oh-my-zsh\nsource \$ZSH/oh-my-zsh.sh" >> "$ZSHRC"

    # Sourcing defined aliases
    echo -e "\n# Source defined aliases\n[ -f \"$HOME/.config/OhMyTermux/aliases\" ] && . \"$HOME/.config/OhMyTermux/aliases\"" >> "$ZSHRC"
}

#------------------------------------------------------------------------------
# INSTALLATION OF ADDITIONAL PACKAGES
#------------------------------------------------------------------------------
install_packages() {
    if $PACKAGES_CHOICE; then
        title_msg "$(t MSG_CONFIG_PACKAGES)"
        local DEFAULT_PACKAGES=("nala" "eza" "bat" "lf" "fzf")
        
        if $USE_GUM; then
            if $FULL_INSTALL; then
                PACKAGES=("${DEFAULT_PACKAGES[@]}")
            else
                # Convert output of gum to array
                IFS=$'\n' read -r -d '' -a PACKAGES < <(gum choose --no-limit \
                    --selected.foreground="33" \
                    --header.foreground="33" \
                    --cursor.foreground="33" \
                    --height=18 \
                    --header="$(t MSG_SELECT_PACKAGES_GUM)" \
                    --selected="nala" --selected="eza" --selected="bat" --selected="lf" --selected="fzf" \
                    "nala" "eza" "colorls" "lsd" "bat" "lf" "fzf" "glow" "tmux" "python" \
                    "nodejs" "nodejs-lts" "micro" "vim" "neovim" "lazygit" "open-ssh" "tsu" \
                    "$(t MSG_ALL_INSTALL)")

                if [[ " ${PACKAGES[*]} " == *" $(t MSG_ALL_INSTALL) "* ]]; then
                    PACKAGES=("nala" "eza" "colorls" "lsd" "bat" "lf" "fzf" "glow" "tmux" "python" \
                            "nodejs" "nodejs-lts" "micro" "vim" "neovim" "lazygit" "open-ssh" "tsu")
                fi
            fi
        else
            echo "$(t MSG_SELECT_PACKAGES_TEXT)"
            echo
            echo -e "${COLOR_BLUE}1)  nala${COLOR_RESET}"
            echo -e "${COLOR_BLUE}2)  eza${COLOR_RESET}"
            echo -e "${COLOR_BLUE}3)  colorls${COLOR_RESET}"
            echo -e "${COLOR_BLUE}4)  lsd${COLOR_RESET}"
            echo -e "${COLOR_BLUE}5)  bat${COLOR_RESET}"
            echo -e "${COLOR_BLUE}6)  lf${COLOR_RESET}"
            echo -e "${COLOR_BLUE}7)  fzf${COLOR_RESET}"
            echo -e "${COLOR_BLUE}8)  glow${COLOR_RESET}"
            echo -e "${COLOR_BLUE}9)  tmux${COLOR_RESET}"
            echo -e "${COLOR_BLUE}10) python${COLOR_RESET}"
            echo -e "${COLOR_BLUE}11) nodejs${COLOR_RESET}"
            echo -e "${COLOR_BLUE}12) nodejs-lts${COLOR_RESET}"
            echo -e "${COLOR_BLUE}13) micro${COLOR_RESET}"
            echo -e "${COLOR_BLUE}14) vim${COLOR_RESET}"
            echo -e "${COLOR_BLUE}15) neovim${COLOR_RESET}"
            echo -e "${COLOR_BLUE}16) lazygit${COLOR_RESET}"
            echo -e "${COLOR_BLUE}17) open-ssh${COLOR_RESET}"
            echo -e "${COLOR_BLUE}18) tsu${COLOR_RESET}"
            echo "19) $(t MSG_ALL_INSTALL)"
            echo            
            printf "${COLOR_GOLD}$(t MSG_ENTER_PACKAGE_NUMBERS_PROMPT) ${COLOR_RESET}"
            tput setaf 3
            read -r -e -p "" -i "1 2 5 6 7" PACKAGE_CHOICES
            tput sgr0
            tput cuu 23
            tput ed
            
            if [[ "$PACKAGE_CHOICES" == *"19"* ]]; then
                PACKAGES=("nala" "eza" "colorls" "lsd" "bat" "lf" "fzf" "glow" "tmux" "python" \
                        "nodejs" "nodejs-lts" "micro" "vim" "neovim" "lazygit" "open-ssh" "tsu")
            else
                PACKAGES=()
                for CHOICE in $PACKAGE_CHOICES; do
                    case $CHOICE in
                        1) PACKAGES+=("nala") ;;
                        2) PACKAGES+=("eza") ;;
                        3) PACKAGES+=("colorls") ;;
                        4) PACKAGES+=("lsd") ;;
                        5) PACKAGES+=("bat") ;;
                        6) PACKAGES+=("lf") ;;
                        7) PACKAGES+=("fzf") ;;
                        8) PACKAGES+=("glow") ;;
                        9) PACKAGES+=("tmux") ;;
                        10) PACKAGES+=("python") ;;
                        11) PACKAGES+=("nodejs") ;;
                        12) PACKAGES+=("nodejs-lts") ;;
                        13) PACKAGES+=("micro") ;;
                        14) PACKAGES+=("vim") ;;
                        15) PACKAGES+=("neovim") ;;
                        16) PACKAGES+=("lazygit") ;;
                        17) PACKAGES+=("open-ssh") ;;
                        18) PACKAGES+=("tsu") ;;
                    esac
                done
            fi
        fi

        if [ ${#PACKAGES[@]} -gt 0 ]; then
            for PACKAGE in "${PACKAGES[@]}"; do
                execute_command "pkg install -y $PACKAGE" "$(t MSG_INSTALLATION_OF) $PACKAGE"

                # Add specific aliases after installation
                case $PACKAGE in
                    eza|bat|nala)
                        add_aliases_to_rc "$PACKAGE"
                        ;;
                esac
            done

            # Reload aliases to make them available immediately
            if [ -f "$HOME/.config/OhMyTermux/aliases" ]; then
                source "$HOME/.config/OhMyTermux/aliases"
            fi
        else
            echo -e "${COLOR_BLUE}$(t MSG_NO_PACKAGE_SELECTED)${COLOR_RESET}"
        fi
    fi
}

#------------------------------------------------------------------------------
# CONFIGURATION OF SPECIFIC ALIASES
#------------------------------------------------------------------------------
add_aliases_to_rc() {
    local PACKAGE=$1
    local ALIASES_FILE="$HOME/.config/OhMyTermux/aliases"
    
    case $PACKAGE in
        eza)
            cat >> "$ALIASES_FILE" << 'EOL'
# Alias eza
alias l="eza --icons"
alias ls="eza -1 --icons"
alias ll="eza -lF -a --icons --total-size --no-permissions --no-time --no-user"
alias la="eza --icons -lgha --group-directories-first"
alias lt="eza --icons --tree"
alias lta="eza --icons --tree -lgha"
alias dir="eza -lF --icons"

EOL
            ;;
        bat)
            cat >> "$ALIASES_FILE" << 'EOL'
# Alias bat
alias cat="bat"

EOL
            ;;
        nala)
            cat >> "$ALIASES_FILE" << 'EOL'
# Alias nala
alias install="nala install -y"
alias uninstall="nala remove -y"
alias update="nala update"
alias upgrade="nala upgrade -y"
alias search="nala search"
alias list="nala list --upgradeable"
alias show="nala show"

EOL
            ;;
    esac
}

#------------------------------------------------------------------------------
# INSTALLATION OF THE FONT
#------------------------------------------------------------------------------
install_font() {
    if $FONT_CHOICE; then
        title_msg "$(t MSG_CONFIG_FONT)"
        if $USE_GUM; then
            FONT=$(gum_choose "$(t MSG_SELECT_FONT_GUM)" --height=13 --selected="Default font" "Default font" "CaskaydiaCove Nerd Font" "FiraMono Nerd Font" "JetBrainsMono Nerd Font" "Mononoki Nerd Font" "VictorMono Nerd Font" "RobotoMono Nerd Font" "DejaVuSansMono Nerd Font" "UbuntuMono Nerd Font" "AnonymousPro Nerd Font" "Terminus Nerd Font")
        else
            echo "$(t MSG_SELECT_FONT_TEXT)"
            echo
            echo -e "${COLOR_BLUE}1)  Default font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}2)  CaskaydiaCove Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}3)  FiraCode Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}4)  Hack Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}5)  JetBrainsMono Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}6)  Meslo Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}7)  RobotoMono Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}8)  SourceCodePro Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}9)  UbuntuMono Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}10) AnonymousPro Nerd Font${COLOR_RESET}"
            echo -e "${COLOR_BLUE}11) Terminus Nerd Font${COLOR_RESET}"
            echo
            printf "${COLOR_GOLD}$(t MSG_ENTER_FONT_NUMBER) : ${COLOR_RESET}"
            tput setaf 3
            read -r -e -p "" -i "1" CHOICE
            tput sgr0
            tput cuu 15
            tput ed
            case $CHOICE in
                1) FONT="Default font" ;;
                2) FONT="CaskaydiaCove Nerd Font" ;;
                3) FONT="FiraCode Nerd Font" ;;
                4) FONT="Hack Nerd Font" ;;
                5) FONT="JetBrainsMono Nerd Font" ;;
                6) FONT="Meslo Nerd Font" ;;
                7) FONT="RobotoMono Nerd Font" ;;
                8) FONT="SourceCodePro Nerd Font" ;;
                9) FONT="UbuntuMono Nerd Font" ;;
                10) FONT="AnonymousPro Nerd Font" ;;
                11) FONT="Terminus Nerd Font" ;;
                *) FONT="Default font" ;;
            esac
        fi

        case $FONT in
            "Default font")
                execute_command "curl -fLo \"$HOME/.termux/font.ttf\" 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf'" "$(t MSG_INSTALLATION_DEFAULT_FONT)"
                termux-reload-settings
                ;;
            *)
                FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/${FONT// /}/Regular/complete/${FONT// /}%20Regular%20Nerd%20Font%20Complete%20Mono.ttf"
                execute_command "curl -L -o $HOME/.termux/font.ttf \"$FONT_URL\"" "$(t MSG_INSTALLATION_FONT) $FONT"
                termux-reload-settings
                ;;
        esac
    fi
}

#------------------------------------------------------------------------------
# INSTALLATION OF THE XFCE ENVIRONMENT
#------------------------------------------------------------------------------
install_xfce() {
    if $XFCE_CHOICE; then
        title_msg "$(t MSG_CONFIG_XFCE)"
        local XFCE_VERSION="recommended"
        local BROWSER_CHOICE="chromium"

        if ! $FULL_INSTALL; then
            if $USE_GUM; then
                if gum_confirm "$(t MSG_CONFIRM_INSTALL_XFCE)"; then
                    # Choice of the version
                    XFCE_VERSION=$(gum_choose "$(t MSG_SELECT_XFCE_VERSION)" --height=5 --selected="recommended" \
                    "minimal" \
                    "recommended" \
                    "customized")

                    # Sélection du navigateur (sauf pour la version minimale)
                    if [ "$XFCE_VERSION" != "minimal" ]; then
                        BROWSER_CHOICE=$(gum_choose "$(t MSG_SELECT_BROWSER)" --height=5 --selected="chromium" "chromium" "firefox" "none")
                    fi
                else
                    return
                fi
            else
                printf "${COLOR_BLUE}$(t MSG_CONFIRM_INSTALL_XFCE) (O/n) : ${COLOR_RESET}"
                read -r -e -p "" -i "o" CHOICE
                if [[ "$CHOICE" =~ ^[oO]$ ]]; then
                    echo -e "${COLOR_BLUE}$(t MSG_SELECT_XFCE_VERSION)${COLOR_RESET}"
                    echo
                    echo "$(t MSG_XFCE_MINIMAL)"
                    echo "$(t MSG_XFCE_RECOMMENDED)"
                    echo "$(t MSG_XFCE_CUSTOMIZED)"
                    echo
                    printf "${COLOR_GOLD}$(t MSG_ENTER_CHOICE_123) : ${COLOR_RESET}"
                    tput setaf 3
                    read -r -e -p "" -i "2" CHOICE
                    tput sgr0
                    tput cuu 7
                    tput ed
                    case $CHOICE in
                        1) XFCE_VERSION="minimal" ;;
                        2) XFCE_VERSION="recommended" ;;
                        3) XFCE_VERSION="customized" ;;
                        *) XFCE_VERSION="recommended" ;;
                    esac

                    if [ "$XFCE_VERSION" != "minimal" ]; then
                        echo -e "${COLOR_BLUE}$(t MSG_SELECT_BROWSER)${COLOR_RESET}"
                        echo
                        echo "$(t MSG_BROWSER_CHROMIUM)"
                        echo "$(t MSG_BROWSER_FIREFOX)"
                        echo "$(t MSG_BROWSER_NONE)"
                        echo
                        printf "${COLOR_GOLD}$(t MSG_ENTER_CHOICE_BROWSER) ${COLOR_RESET}"
                        tput setaf 3
                        read -r -e -p "" -i "1" CHOICE
                        tput sgr0
                        tput cuu 7
                        tput ed
                        case $CHOICE in
                            1) BROWSER_CHOICE="chromium" ;;
                            2) BROWSER_CHOICE="firefox" ;;
                            3) BROWSER_CHOICE="none" ;;
                            *) BROWSER_CHOICE="chromium" ;;
                        esac
                    fi
                else
                    return
                fi
            fi
        fi

        execute_command "pkg install ncurses-ui-libs && pkg uninstall dbus -y" "$(t MSG_INSTALL_DEPENDENCIES)"

        PACKAGES=('wget' 'x11-repo' 'tur-repo' 'pulseaudio')

        for PACKAGE in "${PACKAGES[@]}"; do
            execute_command "pkg install -y $PACKAGE" "$(t MSG_INSTALLATION_OF) $PACKAGE"
        done

        if $USE_GUM; then
            download_and_execute "https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/xfce.sh" "XFCE" --gum --version="$XFCE_VERSION" --browser="$BROWSER_CHOICE"
        else
            download_and_execute "https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/xfce.sh" "XFCE" --version="$XFCE_VERSION" --browser="$BROWSER_CHOICE"
        fi
    fi
}

#------------------------------------------------------------------------------
# INSTALLATION OF THE XFCE SCRIPTS
#------------------------------------------------------------------------------
install_xfce_scripts() {
    title_msg "$(t MSG_CONFIG_XFCE_SCRIPTS)"
    
    # Installation of the start script
    cat <<'EOF' > start
#!/bin/bash

# Activate PulseAudio on the network
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 > /dev/null 2>&1

XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :1.0 & > /dev/null 2>&1
sleep 1

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 virgl_test_server_android --angle-gl & > /dev/null 2>&1

env DISPLAY=:1.0 GALLIUM_DRIVER=virpipe dbus-launch --exit-with-session xfce4-session & > /dev/null 2>&1

# Set the audio server
export PULSE_SERVER=127.0.0.1 > /dev/null 2>&1

sleep 5
process_id=$(ps -aux | grep '[x]fce4-screensaver' | awk '{print $2}')
kill "$process_id" > /dev/null 2>&1
EOF

    execute_command "chmod +x start && mv start $PREFIX/bin" "$(t MSG_INSTALL_START_SCRIPT)"

    # Installation of the stop script
    cat <<'EOF' > "$PREFIX/bin/kill_termux_x11"
#!/bin/bash

# Check the execution of the processes in Termux or Proot
if pgrep -f 'apt|apt-get|dpkg|nala' > /dev/null; then
    zenity --info --text="A software is being installed in Termux or Proot. Please wait for these processes to finish before continuing."
    exit 1
fi

# Get the identifiers of the Termux-X11 and XFCE processes
termux_x11_pid=$(pgrep -f /system/bin/app_process.*com.termux.x11.Loader)
xfce_pid=$(pgrep -f "xfce4-session")

# Stop the processes only if they exist
if [ -n "$termux_x11_pid" ]; then
    kill -9 "$termux_x11_pid" 2>/dev/null
fi

if [ -n "$xfce_pid" ]; then
    kill -9 "$xfce_pid" 2>/dev/null
fi

# Display dynamic message
if [ -n "$termux_x11_pid" ] || [ -n "$xfce_pid" ]; then
    zenity --info --text="Termux-X11 and XFCE sessions closed."
else
    zenity --info --text="Termux-X11 or XFCE session not found."
fi

# Stop the Termux application only if the PID exists
info_output=$(termux-info)
if pid=$(echo "$info_output" | grep -o 'TERMUX_APP_PID=[0-9]\+' | awk -F= '{print $2}') && [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null
fi

exit 0

EOF

    execute_command "chmod +x $PREFIX/bin/kill_termux_x11" "$(t MSG_INSTALL_STOP_SCRIPT)"


    # Creation of the shortcut
    mkdir -p "$PREFIX/share/applications"
    cat <<'EOF' > "$PREFIX/share/applications/kill_termux_x11.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Stop
Comment=
Exec=kill_termux_x11
Icon=shutdown
Categories=System;
Path=
StartupNotify=false
EOF

    execute_command "chmod +x $PREFIX/share/applications/kill_termux_x11.desktop" "$(t MSG_CREATE_SHORTCUT)"
}

#------------------------------------------------------------------------------
# INSTALLATION DE DEBIAN PROOT
#------------------------------------------------------------------------------
install_proot() {
    if $PROOT_CHOICE; then
        title_msg "$(t MSG_CONFIG_PROOT)"
        
        execute_command "curl -O https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/proot.sh" "$(t MSG_DOWNLOAD_PROOT_SCRIPT)" || error_msg "$(t MSG_ERROR_DOWNLOAD_PROOT)"
        execute_command "chmod +x proot.sh" "$(t MSG_EXECUTE_PROOT_SCRIPT)"
        
        # If the identifiers are already provided
        if [ -n "$PROOT_USERNAME" ] && [ -n "$PROOT_PASSWORD" ]; then
            if $USE_GUM; then
                execute_command "pkg install proot-distro -y" "$(t MSG_INSTALL_PROOT_DISTRO)"
                download_and_execute "https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/proot.sh" "PRoot" --gum --username="$PROOT_USERNAME" --password="$PROOT_PASSWORD"
                install_utils
            else
                execute_command "pkg install proot-distro -y" "$(t MSG_INSTALL_PROOT_DISTRO)"
                download_and_execute "https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/proot.sh" "PRoot" --username="$PROOT_USERNAME" --password="$PROOT_PASSWORD"
                install_utils
            fi
        else
            if $USE_GUM; then
                if gum_confirm "$(t MSG_CONFIRM_INSTALL_PROOT)"; then
                    execute_command "pkg install proot-distro -y" "$(t MSG_INSTALL_PROOT_DISTRO)"
                    download_and_execute "https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/proot.sh" "PRoot" --gum
                    install_utils
                fi
            else    
                printf "${COLOR_BLUE}$(t MSG_CONFIRM_INSTALL_PROOT) (O/n) : ${COLOR_RESET}"
                read -r -e -p "" -i "o" CHOICE
                tput cuu1
                tput el
                if [[ "$CHOICE" =~ ^[oO]$ ]]; then
                    execute_command "pkg install proot-distro -y" "$(t MSG_INSTALL_PROOT_DISTRO)"
                    ./proot.sh
                    install_utils
                fi
            fi
        fi
    fi
}

#------------------------------------------------------------------------------
# GETTING THE USERNAME
#------------------------------------------------------------------------------
get_username() {
    local USER_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home"
    local USERNAME
    USERNAME=$(ls -1 "$USER_DIR" 2>/dev/null | grep -v '^$' | head -n 1)
    if [ -z "$USERNAME" ]; then
        echo "$(t MSG_ERROR_NO_USER_FOUND)" >&2
        return 1
    fi
    echo "$USERNAME"
}

#------------------------------------------------------------------------------
# INSTALLATION OF THE UTILITIES
#------------------------------------------------------------------------------
install_utils() {
    title_msg "$(t MSG_CONFIG_UTILS)"
    download_and_execute "https://raw.githubusercontent.com/devohmycode/OhMyTermux/$BRANCH/utils.sh" "Utils"

    if ! USERNAME=$(get_username); then
        error_msg "$(t MSG_ERROR_GET_USERNAME)"
        return 1
    fi

    BASHRC_PROOT="${PREFIX}/var/lib/proot-distro/installed-rootfs/debian/home/${USERNAME}/.bashrc"
    if [ ! -f "$BASHRC_PROOT" ]; then
        error_msg "$(t MSG_ERROR_BASHRC_NOT_EXISTS) $USERNAME."
        execute_command "proot-distro login debian --shared-tmp --env DISPLAY=:1.0 -- touch \"$BASHRC_PROOT\"" "$(t MSG_CONFIG_BASH_DEBIAN)"
    fi

    cat << "EOL" >> "$BASHRC_PROOT"

export DISPLAY=:1.0

alias zink="MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform"
alias hud="GALLIUM_HUD=fps"
alias ..="cd .."
alias l="ls -CF"
alias ll="ls -l"
alias la="ls -A"
alias q="exit"
alias s="source"
alias c="clear"
alias cat="bat"
alias apt="sudo nala"
alias install="sudo nala install -y"
alias update="sudo nala update"
alias upgrade="sudo nala upgrade -y"
alias remove="sudo nala remove -y"
alias list="nala list --upgradeable"
alias show="nala show"
alias search="nala search"
alias start='echo "Please run from Termux and not Debian proot."'
alias cm="chmod +x"
alias clone="git clone"
alias push="git pull && git add . && git commit -m 'mobile push' && git push"
alias g="git"
alias n="nano"
alias bashrc="nano \$HOME/.bashrc"
EOL

    USERNAME=$(get_username)

    TMP_FILE="${TMPDIR}/rc_content"
    touch "$TMP_FILE"

    cat << EOL >> "$TMP_FILE"

# Alias to connect to Debian Proot
alias debian="proot-distro login debian --shared-tmp --user ${USERNAME}"
EOL

    if [ -f "$BASHRC" ]; then
        cat "$TMP_FILE" >> "$BASHRC"
        success_msg "$(t MSG_CONFIG_BASH_TERMUX)"
    else
        touch "$BASHRC" 
        cat "$TMP_FILE" >> "$BASHRC"
        success_msg "$(t MSG_CREATE_CONFIG_BASH_TERMUX)"
    fi
    if [ -f "$ZSHRC" ]; then
        cat "$TMP_FILE" >> "$ZSHRC"
        success_msg "$(t MSG_CONFIG_ZSH_TERMUX)"
    else
        touch "$ZSHRC"
        cat "$TMP_FILE" >> "$ZSHRC"
        success_msg "$(t MSG_CREATE_CONFIG_ZSH_TERMUX)"
    fi
    rm "$TMP_FILE"
}

#------------------------------------------------------------------------------
# INSTALLATION OF TERMUX-X11
#------------------------------------------------------------------------------
install_termux_x11() {
    if $X11_CHOICE; then
        title_msg "$(t MSG_CONFIG_TERMUX_X11)"
        local FILE_PATH="$HOME/.termux/termux.properties"
    
        if [ ! -f "$FILE_PATH" ]; then
            mkdir -p "$HOME/.termux"
            cat <<EOL > "$FILE_PATH"
allow-external-apps = true
EOL
        else
            sed -i 's/^# allow-external-apps = true/allow-external-apps = true/' "$FILE_PATH"
        fi
    fi

    local INSTALL_X11=false

    if $X11_CHOICE; then
        if $USE_GUM; then
            if gum_confirm "$(t MSG_CONFIRM_INSTALL_TERMUX_X11)"; then
                INSTALL_X11=true
            fi
        else
            printf "${COLOR_BLUE}$(t MSG_CONFIRM_INSTALL_TERMUX_X11) (O/n) : ${COLOR_RESET}"
            read -r -e -p "" -i "n" choice
            tput cuu1
            tput el
            if [[ "$choice" =~ ^[oO]$ ]]; then
                INSTALL_X11=true
            fi
        fi

        if $INSTALL_X11; then
            local APK_URL="https://github.com/termux/termux-x11/releases/download/nightly/app-arm64-v8a-debug.apk"
            local APK_FILE="$HOME/storage/downloads/termux-x11.apk"

            execute_command "wget \"$APK_URL\" -O \"$APK_FILE\"" "$(t MSG_DOWNLOAD_TERMUX_X11)"

            if [ -f "$APK_FILE" ]; then
                termux-open "$APK_FILE"
                echo -e "${COLOR_BLUE}$(t MSG_INSTALL_APK_MANUALLY)${COLOR_RESET}"
                echo -e "${COLOR_BLUE}$(t MSG_INSTALL_COMPLETE_PRESS_ENTER)${COLOR_RESET}"
                read -r
                rm "$APK_FILE"
            else
                error_msg "$(t MSG_ERROR_TERMUX_X11_INSTALL)"
            fi
        fi
    fi
}

#------------------------------------------------------------------------------
# MAIN FUNCTION
#------------------------------------------------------------------------------

show_banner

# Checking and installing the necessary dependencies
if ! command -v tput &> /dev/null; then
    if $USE_GUM; then
        execute_command "pkg install -y ncurses-utils" "Installation of the dependencies"
    else
        info_msg "Installation of the dependencies"
        pkg install -y ncurses-utils >/dev/null 2>&1
    fi
fi

# Checking if specific arguments have been provided
if [ "$SHELL_CHOICE" = true ] || [ "$PACKAGES_CHOICE" = true ] || [ "$FONT_CHOICE" = true ] || [ "$XFCE_CHOICE" = true ] || [ "$PROOT_CHOICE" = true ] || [ "$X11_CHOICE" = true ]; then
    if $EXECUTE_INITIAL_CONFIG; then
        initial_config
    fi
    if [ "$SHELL_CHOICE" = true ]; then
        install_shell
    fi
    if [ "$PACKAGES_CHOICE" = true ]; then
        install_packages
    fi
    if [ "$FONT_CHOICE" = true ]; then
        install_font
    fi
    if [ "$XFCE_CHOICE" = true ]; then
        install_xfce
    fi
    if [ "$XFCE_CHOICE" = true ] && [ "$PROOT_CHOICE" = false ]; then
        install_xfce_scripts
    fi
    if [ "$PROOT_CHOICE" = true ]; then
        install_proot
    fi
    if [ "$X11_CHOICE" = true ]; then
        install_termux_x11
    fi
else
    # Execute the complete installation if no specific argument is provided
    if $EXECUTE_INITIAL_CONFIG; then
        initial_config
    fi
    install_shell
    common_alias
    install_packages
    install_font
    install_xfce
    install_proot
    install_termux_x11
fi

# Cleaning and end message
title_msg "❯ Saving the installation scripts"
mkdir -p $HOME/.config/OhMyTermux >/dev/null 2>&1
mv -f xfce.sh proot.sh utils.sh install.sh $HOME/.config/OhMyTermux/ >/dev/null 2>&1
rm -f xfce.sh proot.sh utils.sh install.sh >/dev/null 2>&1

# Clean up downloaded i18n files if they were downloaded during installation
if [ -d "$SCRIPT_DIR/i18n" ] && [ "$MESSAGES_LOADED" != "fallback" ]; then
    mv -f "$SCRIPT_DIR/i18n" "$HOME/.config/OhMyTermux/" >/dev/null 2>&1
fi

# Rechargement du shell
if $USE_GUM; then
    if gum_confirm "Execute OhMyTermux ?"; then
        clear
        if [ "$SHELL_CHOICE" = "zsh" ]; then
            exec zsh -l
        else
            exec $SHELL_CHOICE
        fi
    else
        echo -e "${COLOR_BLUE}$(t MSG_TO_USE_ALL_FEATURES)${COLOR_RESET}"
        echo -e "${COLOR_BLUE}$(t MSG_ENTER_EXEC_ZSH)${COLOR_RESET}"
        echo -e "${COLOR_BLUE}$(t MSG_OR_RESTART_TERMUX)${COLOR_RESET}"
    fi
else
    printf "${COLOR_BLUE}$(t MSG_CONFIRM_EXECUTE_OHMYTERMUX) ${COLOR_RESET}"
    read -r -e -p "" -i "o" choice
    if [[ "$choice" =~ ^[oO]$ ]]; then
        clear
        if [ "$SHELL_CHOICE" = true ]; then
            exec zsh -l
        else
            exec $SHELL_CHOICE
        fi
    else
        tput cuu1
        tput el
        echo -e "${COLOR_BLUE}$(t MSG_TO_USE_ALL_FEATURES)${COLOR_RESET}"
        echo -e "${COLOR_BLUE}$(t MSG_ENTER_EXEC_ZSH)${COLOR_RESET}"
        echo -e "${COLOR_BLUE}$(t MSG_OR_RESTART_TERMUX)${COLOR_RESET}"
    fi
fi