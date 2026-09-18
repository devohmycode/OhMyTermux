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
# TERMINAL QUERY REPLIES
#------------------------------------------------------------------------------
# gum probes the terminal for synchronized output (mode 2026) and grapheme
# clustering (mode 2027). A terminal that supports DECRQM answers on stdin, but
# `gum spin` usually exits before reading the reply: the bytes are echoed as
# ^[[?2026;2$y on the line that follows and stay queued, where they would be
# picked up by the next read. The Termux terminal stays silent, so this only
# shows up under terminals that implement DECRQM (Docker images, desktop hosts).

# Discard input already waiting in the terminal queue
flush_terminal_input() {
    [ -t 0 ] || return 0
    local _discard _guard=0
    # read -t 0 reports pending input without consuming any of it
    while read -r -s -t 0 _discard 2>/dev/null; do
        read -r -s -t 0.05 -n 4096 _discard 2>/dev/null
        _guard=$((_guard + 1))
        [ "$_guard" -ge 10 ] && break
    done
    return 0
}

# Erase the current line, removing anything the terminal echoed onto it
clear_terminal_line() {
    [ -t 1 ] || return 0
    printf '\r'
    tput el 2>/dev/null
    return 0
}

#------------------------------------------------------------------------------
# REDIRECTION
#------------------------------------------------------------------------------
if [ "$VERBOSE" = true ]; then
    REDIRECT=""
else
    REDIRECT="> /dev/null 2>&1"
fi
