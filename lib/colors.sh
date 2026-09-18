#!/bin/bash
#------------------------------------------------------------------------------
# DISPLAY COLORS
#------------------------------------------------------------------------------
COLOR_BLUE='\033[38;5;33m'    # Information
COLOR_GREEN='\033[38;5;82m'   # Success
COLOR_GOLD='\033[38;5;220m'   # Warning
COLOR_RED='\033[38;5;196m'    # Error
COLOR_RESET='\033[0m'         # Reset

#------------------------------------------------------------------------------
# TPUT FALLBACK
#------------------------------------------------------------------------------
# tput belongs to the ncurses-utils package, which is absent from a bare Termux
# install. Until it is installed, emit the equivalent ANSI sequences so cursor
# and color handling never break. Overridden by the real binary once available.
if ! type -P tput &>/dev/null; then
    tput() {
        local CAP="$1"
        local ARG="$2"
        local ESC=$'\033'
        case "$CAP" in
            cuu1)  printf '%s[A' "$ESC" ;;
            cud1)  printf '%s[B' "$ESC" ;;
            cuu)   printf '%s[%sA' "$ESC" "${ARG:-1}" ;;
            cud)   printf '%s[%sB' "$ESC" "${ARG:-1}" ;;
            el)    printf '%s[K' "$ESC" ;;
            ed)    printf '%s[J' "$ESC" ;;
            sc)    printf '%s7' "$ESC" ;;
            rc)    printf '%s8' "$ESC" ;;
            sgr0)  printf '%s[0m' "$ESC" ;;
            setaf) printf '%s[38;5;%sm' "$ESC" "${ARG:-7}" ;;
            setab) printf '%s[48;5;%sm' "$ESC" "${ARG:-0}" ;;
            civis) printf '%s[?25l' "$ESC" ;;
            cnorm) printf '%s[?25h' "$ESC" ;;
            clear) printf '%s[H%s[2J' "$ESC" "$ESC" ;;
            cols)  printf '%s\n' "${COLUMNS:-80}" ;;
            lines) printf '%s\n' "${LINES:-24}" ;;
            *)     return 0 ;;
        esac
    }
fi

#------------------------------------------------------------------------------
# REDIRECTION
#------------------------------------------------------------------------------
if [ "$VERBOSE" = true ]; then
    REDIRECT=""
else
    REDIRECT="> /dev/null 2>&1"
fi
