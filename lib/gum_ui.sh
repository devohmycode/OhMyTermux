#!/bin/bash
#------------------------------------------------------------------------------
# GUM CONFIRMATION
#------------------------------------------------------------------------------
gum_confirm() {
    local PROMPT="$1"
    if ${FULL_INSTALL:-false}; then
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

    if ${FULL_INSTALL:-false}; then
        if [ -n "$SELECTED" ]; then
            echo "$SELECTED"
        else
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

    if ${FULL_INSTALL:-false}; then
        if [ -n "$SELECTED" ]; then
            echo "$SELECTED"
        else
            echo "${OPTIONS[@]}"
        fi
    else
        gum choose --no-limit --selected.foreground="33" --header.foreground="33" --cursor.foreground="33" --height="$HEIGHT" --header="$PROMPT" --selected="$SELECTED" "${OPTIONS[@]}"
    fi
}
