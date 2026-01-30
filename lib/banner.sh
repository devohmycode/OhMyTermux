#!/bin/bash
#------------------------------------------------------------------------------
# TEXT MODE BANNER
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
        local TITLE="${BANNER_TITLE:-OHMYTERMUX}"
        gum style \
            --foreground 33 \
            --border-foreground 33 \
            --border double \
            --align center \
            --width 42 \
            --margin "1 1 1 0" \
            "" "$TITLE" ""
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
        local ERR_KEY="${ERROR_MSG_KEY:-MSG_ERROR_INSTALL}"
        local REF_KEY="${ERROR_REFER_KEY:-MSG_ERROR_REFER_MESSAGES}"
        if $USE_GUM; then
            gum style --foreground 196 "$(t "$ERR_KEY")"
        else
            echo -e "${COLOR_RED}$(t "$ERR_KEY")${COLOR_RESET}"
        fi
        echo -e "${COLOR_BLUE}$(t "$REF_KEY")${COLOR_RESET}"
    fi
}
