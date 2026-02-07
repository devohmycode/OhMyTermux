#!/bin/bash
#------------------------------------------------------------------------------
# PLUGIN: theme-catppuccin - Installation script
# Applies Catppuccin color theme to Termux terminal
#------------------------------------------------------------------------------

install_catppuccin() {
    local VARIANT=""
    local VARIANTS=("Mocha" "Latte" "Frappe" "Macchiato")

    if $USE_GUM; then
        VARIANT=$(gum_choose "$(t MSG_CATPPUCCIN_SELECT_VARIANT)" \
            --height=6 --selected="Mocha" \
            "Mocha" "Latte" "Frappe" "Macchiato")
    else
        echo -e "${COLOR_BLUE}$(t MSG_CATPPUCCIN_SELECT_VARIANT)${COLOR_RESET}"
        echo
        echo -e "${COLOR_BLUE}1) Mocha $(t MSG_CATPPUCCIN_MOCHA_DESC)${COLOR_RESET}"
        echo -e "${COLOR_BLUE}2) Latte $(t MSG_CATPPUCCIN_LATTE_DESC)${COLOR_RESET}"
        echo -e "${COLOR_BLUE}3) Frappe $(t MSG_CATPPUCCIN_FRAPPE_DESC)${COLOR_RESET}"
        echo -e "${COLOR_BLUE}4) Macchiato $(t MSG_CATPPUCCIN_MACCHIATO_DESC)${COLOR_RESET}"
        echo
        printf "${COLOR_GOLD}$(t MSG_ENTER_CHOICE_123) ${COLOR_RESET}"
        tput setaf 3
        read -r -e -p "" -i "1" CHOICE
        tput sgr0
        tput cuu 8
        tput ed

        case $CHOICE in
            1) VARIANT="Mocha" ;;
            2) VARIANT="Latte" ;;
            3) VARIANT="Frappe" ;;
            4) VARIANT="Macchiato" ;;
            *) VARIANT="Mocha" ;;
        esac
    fi

    success_msg "$(t MSG_CATPPUCCIN_SELECTED) $VARIANT"

    local TERMUX_DIR="$HOME/.termux"
    mkdir -p "$TERMUX_DIR"

    case "$VARIANT" in
        "Mocha")
            cat > "$TERMUX_DIR/colors.properties" << 'EOF'
# Catppuccin Mocha
foreground=#CDD6F4
background=#1E1E2E
cursor=#F5E0DC
color0=#45475A
color1=#F38BA8
color2=#A6E3A1
color3=#F9E2AF
color4=#89B4FA
color5=#F5C2E7
color6=#94E2D5
color7=#BAC2DE
color8=#585B70
color9=#F38BA8
color10=#A6E3A1
color11=#F9E2AF
color12=#89B4FA
color13=#F5C2E7
color14=#94E2D5
color15=#A6ADC8
EOF
            ;;
        "Latte")
            cat > "$TERMUX_DIR/colors.properties" << 'EOF'
# Catppuccin Latte
foreground=#4C4F69
background=#EFF1F5
cursor=#DC8A78
color0=#5C5F77
color1=#D20F39
color2=#40A02B
color3=#DF8E1D
color4=#1E66F5
color5=#EA76CB
color6=#179299
color7=#ACB0BE
color8=#6C6F85
color9=#D20F39
color10=#40A02B
color11=#DF8E1D
color12=#1E66F5
color13=#EA76CB
color14=#179299
color15=#BCC0CC
EOF
            ;;
        "Frappe")
            cat > "$TERMUX_DIR/colors.properties" << 'EOF'
# Catppuccin Frappe
foreground=#C6D0F5
background=#303446
cursor=#F2D5CF
color0=#51576D
color1=#E78284
color2=#A6D189
color3=#E5C890
color4=#8CAAEE
color5=#F4B8E4
color6=#81C8BE
color7=#B5BFE2
color8=#626880
color9=#E78284
color10=#A6D189
color11=#E5C890
color12=#8CAAEE
color13=#F4B8E4
color14=#81C8BE
color15=#A5ADCE
EOF
            ;;
        "Macchiato")
            cat > "$TERMUX_DIR/colors.properties" << 'EOF'
# Catppuccin Macchiato
foreground=#CAD3F5
background=#24273A
cursor=#F4DBD6
color0=#494D64
color1=#ED8796
color2=#A6DA95
color3=#EED49F
color4=#8AADF4
color5=#F5BDE6
color6=#8BD5CA
color7=#B8C0E0
color8=#5B6078
color9=#ED8796
color10=#A6DA95
color11=#EED49F
color12=#8AADF4
color13=#F5BDE6
color14=#8BD5CA
color15=#A5ADCB
EOF
            ;;
    esac

    success_msg "$(t MSG_CATPPUCCIN_APPLIED) $VARIANT"
    termux-reload-settings 2>/dev/null || true
}

install_catppuccin
