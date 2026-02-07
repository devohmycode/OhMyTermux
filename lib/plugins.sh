#!/bin/bash
#------------------------------------------------------------------------------
# PLUGIN SYSTEM ENGINE
# Discovers, registers, and executes third-party plugins from plugins/
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# PLUGIN REGISTRIES
#------------------------------------------------------------------------------
declare -A PLUGIN_REGISTRY 2>/dev/null || true
declare -A PLUGIN_VERSION 2>/dev/null || true
declare -A PLUGIN_DESCRIPTION 2>/dev/null || true
declare -A PLUGIN_ENABLED 2>/dev/null || true
declare -A PLUGIN_DEPENDENCIES 2>/dev/null || true
declare -A PLUGIN_CLI_FLAG 2>/dev/null || true
declare -A PLUGIN_CLI_SHORT 2>/dev/null || true
declare -A PLUGIN_CHOICE_VAR 2>/dev/null || true
declare -A PLUGIN_PRIORITY 2>/dev/null || true

# Hook registry: hook_name -> "plugin1:callback1 plugin2:callback2 ..."
declare -A HOOK_REGISTRY 2>/dev/null || true

# Resolved plugin execution order
PLUGIN_ORDER=()

# Remaining args after plugin arg parsing
REMAINING_ARGS=()

# Plugins directory
PLUGINS_DIR="${PLUGINS_DIR:-$SCRIPT_DIR/plugins}"

#------------------------------------------------------------------------------
# REGISTER A PLUGIN
# Called from manifest.sh with named arguments
# Usage: register_plugin --name "foo" --version "1.0" --description "..." \
#          --cli-flag "--foo" --cli-short "-fo" --priority 50
#------------------------------------------------------------------------------
register_plugin() {
    local NAME="" VERSION="1.0.0" DESCRIPTION="" DEPENDS="" CLI_FLAG="" CLI_SHORT="" PRIORITY=50

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)      NAME="$2"; shift 2 ;;
            --version)   VERSION="$2"; shift 2 ;;
            --description) DESCRIPTION="$2"; shift 2 ;;
            --depends)   DEPENDS="$2"; shift 2 ;;
            --cli-flag)  CLI_FLAG="$2"; shift 2 ;;
            --cli-short) CLI_SHORT="$2"; shift 2 ;;
            --priority)  PRIORITY="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$NAME" ]; then
        echo "Warning: register_plugin called without --name" >&2
        return 1
    fi

    PLUGIN_REGISTRY["$NAME"]=1
    PLUGIN_VERSION["$NAME"]="$VERSION"
    PLUGIN_DESCRIPTION["$NAME"]="$DESCRIPTION"
    PLUGIN_ENABLED["$NAME"]=false
    PLUGIN_DEPENDENCIES["$NAME"]="$DEPENDS"
    PLUGIN_PRIORITY["$NAME"]="$PRIORITY"

    # Generate CLI flag from name if not provided
    if [ -z "$CLI_FLAG" ]; then
        CLI_FLAG="--${NAME}"
    fi
    PLUGIN_CLI_FLAG["$NAME"]="$CLI_FLAG"
    PLUGIN_CLI_SHORT["$NAME"]="$CLI_SHORT"

    # Generate choice variable name
    local VAR_NAME
    VAR_NAME="PLUGIN_$(echo "$NAME" | tr '[:lower:]-' '[:upper:]_')_CHOICE"
    PLUGIN_CHOICE_VAR["$NAME"]="$VAR_NAME"
    eval "$VAR_NAME=false"
}

#------------------------------------------------------------------------------
# HOOK SYSTEM
#------------------------------------------------------------------------------

# Register a callback on a hook
# Usage: plugin_hook "post_install" "my_plugin" "my_callback_function"
plugin_hook() {
    local HOOK_NAME="$1"
    local PLUGIN_NAME="$2"
    local CALLBACK="$3"

    local ENTRY="${PLUGIN_NAME}:${CALLBACK}"
    if [ -z "${HOOK_REGISTRY[$HOOK_NAME]+x}" ]; then
        HOOK_REGISTRY["$HOOK_NAME"]="$ENTRY"
    else
        HOOK_REGISTRY["$HOOK_NAME"]="${HOOK_REGISTRY[$HOOK_NAME]} $ENTRY"
    fi
}

# Execute all callbacks registered for a hook (only for enabled plugins)
# Usage: run_hook "post_install"
run_hook() {
    local HOOK_NAME="$1"

    if [ -z "${HOOK_REGISTRY[$HOOK_NAME]+x}" ]; then
        return 0
    fi

    local ENTRIES="${HOOK_REGISTRY[$HOOK_NAME]}"
    for ENTRY in $ENTRIES; do
        local PLUGIN_NAME="${ENTRY%%:*}"
        local CALLBACK="${ENTRY#*:}"

        # Only run hooks for enabled plugins
        if [ "${PLUGIN_ENABLED[$PLUGIN_NAME]}" = "true" ]; then
            if type "$CALLBACK" &>/dev/null; then
                "$CALLBACK"
            fi
        fi
    done
}

#------------------------------------------------------------------------------
# PLUGIN DISCOVERY
# Scans plugins/*/manifest.sh and sources them
#------------------------------------------------------------------------------
discover_plugins() {
    if [ ! -d "$PLUGINS_DIR" ]; then
        return 0
    fi

    local MANIFEST
    for MANIFEST in "$PLUGINS_DIR"/*/manifest.sh; do
        [ -f "$MANIFEST" ] || continue
        source "$MANIFEST"
    done
}

#------------------------------------------------------------------------------
# RESOLVE PLUGIN ORDER
# Sort by dependencies + priority (simple topological sort)
#------------------------------------------------------------------------------
resolve_plugin_order() {
    PLUGIN_ORDER=()
    local -A VISITED
    local -A IN_STACK

    _resolve_visit() {
        local NAME="$1"
        if [ "${IN_STACK[$NAME]+x}" ]; then
            echo "Warning: circular dependency detected for plugin '$NAME'" >&2
            return 0
        fi
        if [ "${VISITED[$NAME]+x}" ]; then
            return 0
        fi
        IN_STACK["$NAME"]=1

        # Visit dependencies first
        local DEPS="${PLUGIN_DEPENDENCIES[$NAME]}"
        if [ -n "$DEPS" ]; then
            local DEP
            for DEP in $DEPS; do
                if [ "${PLUGIN_REGISTRY[$DEP]+x}" ]; then
                    _resolve_visit "$DEP"
                fi
            done
        fi

        unset "IN_STACK[$NAME]"
        VISITED["$NAME"]=1
        PLUGIN_ORDER+=("$NAME")
    }

    # Sort plugins by priority first, then visit
    local SORTED_PLUGINS
    SORTED_PLUGINS=$(
        for NAME in "${!PLUGIN_REGISTRY[@]}"; do
            echo "${PLUGIN_PRIORITY[$NAME]:-50} $NAME"
        done | sort -n | awk '{print $2}'
    )

    local NAME
    for NAME in $SORTED_PLUGINS; do
        _resolve_visit "$NAME"
    done
}

#------------------------------------------------------------------------------
# LOAD PLUGIN I18N
# Sources messages/{lang}.sh from a plugin directory
#------------------------------------------------------------------------------
load_plugin_i18n() {
    local PLUGIN_NAME="$1"
    local LANG="${CURRENT_LANG:-en}"

    local MSG_FILE="$PLUGINS_DIR/$PLUGIN_NAME/messages/${LANG}.sh"
    if [ -f "$MSG_FILE" ]; then
        source "$MSG_FILE"
        return 0
    fi

    # Fallback to English
    MSG_FILE="$PLUGINS_DIR/$PLUGIN_NAME/messages/en.sh"
    if [ -f "$MSG_FILE" ]; then
        source "$MSG_FILE"
    fi
}

# Load i18n for all registered plugins
load_all_plugin_i18n() {
    local NAME
    for NAME in "${!PLUGIN_REGISTRY[@]}"; do
        load_plugin_i18n "$NAME"
    done
}

#------------------------------------------------------------------------------
# PARSE PLUGIN CLI ARGUMENTS
# Pre-parses args for plugin flags, stores remaining in REMAINING_ARGS
#------------------------------------------------------------------------------
parse_plugin_args() {
    REMAINING_ARGS=()

    while [[ $# -gt 0 ]]; do
        local MATCHED=false
        local NAME

        for NAME in "${!PLUGIN_REGISTRY[@]}"; do
            local FLAG="${PLUGIN_CLI_FLAG[$NAME]}"
            local SHORT="${PLUGIN_CLI_SHORT[$NAME]}"

            if [ "$1" = "$FLAG" ] || { [ -n "$SHORT" ] && [ "$1" = "$SHORT" ]; }; then
                PLUGIN_ENABLED["$NAME"]=true
                local VAR="${PLUGIN_CHOICE_VAR[$NAME]}"
                eval "$VAR=true"
                ONLY_GUM=false
                MATCHED=true
                break
            fi
        done

        if ! $MATCHED; then
            REMAINING_ARGS+=("$1")
        fi
        shift
    done
}

#------------------------------------------------------------------------------
# SHOW PLUGIN HELP
# Displays available plugin flags in --help output
#------------------------------------------------------------------------------
show_plugin_help() {
    if [ ${#PLUGIN_REGISTRY[@]} -eq 0 ]; then
        return 0
    fi

    echo
    if type t &>/dev/null; then
        echo "$(t MSG_PLUGIN_HELP_HEADER)"
    else
        echo "Plugins:"
    fi

    local NAME
    for NAME in "${!PLUGIN_REGISTRY[@]}"; do
        local FLAG="${PLUGIN_CLI_FLAG[$NAME]}"
        local SHORT="${PLUGIN_CLI_SHORT[$NAME]}"
        local DESC="${PLUGIN_DESCRIPTION[$NAME]}"

        if [ -n "$SHORT" ]; then
            printf "  %-12s %-5s %s\n" "$FLAG" "$SHORT" "$DESC"
        else
            printf "  %-18s %s\n" "$FLAG" "$DESC"
        fi
    done
}

#------------------------------------------------------------------------------
# PLUGIN SELECTION (GUM or TEXT)
# Interactive multi-select for available plugins
#------------------------------------------------------------------------------
show_plugin_selection_gum() {
    if [ ${#PLUGIN_REGISTRY[@]} -eq 0 ]; then
        return 0
    fi

    # Skip if any plugin was already enabled via CLI
    local ANY_ENABLED=false
    local NAME
    for NAME in "${!PLUGIN_REGISTRY[@]}"; do
        if [ "${PLUGIN_ENABLED[$NAME]}" = "true" ]; then
            ANY_ENABLED=true
            break
        fi
    done
    if $ANY_ENABLED; then
        return 0
    fi

    local PLUGIN_NAMES=()
    local PLUGIN_LABELS=()
    for NAME in $(echo "${!PLUGIN_REGISTRY[@]}" | tr ' ' '\n' | sort); do
        PLUGIN_NAMES+=("$NAME")
        PLUGIN_LABELS+=("$NAME - ${PLUGIN_DESCRIPTION[$NAME]}")
    done

    if [ ${#PLUGIN_NAMES[@]} -eq 0 ]; then
        return 0
    fi

    local HEADER
    if type t &>/dev/null; then
        HEADER="$(t MSG_PLUGIN_SELECT_PROMPT)"
    else
        HEADER="Select plugins to install:"
    fi

    if $USE_GUM; then
        local SELECTED
        SELECTED=$(printf '%s\n' "${PLUGIN_LABELS[@]}" | gum choose --no-limit \
            --selected.foreground="33" \
            --header.foreground="33" \
            --cursor.foreground="33" \
            --height=$((${#PLUGIN_LABELS[@]} + 2)) \
            --header="$HEADER" 2>/dev/null) || true

        if [ -n "$SELECTED" ]; then
            while IFS= read -r LINE; do
                local SELECTED_NAME="${LINE%% - *}"
                if [ "${PLUGIN_REGISTRY[$SELECTED_NAME]+x}" ]; then
                    PLUGIN_ENABLED["$SELECTED_NAME"]=true
                    local VAR="${PLUGIN_CHOICE_VAR[$SELECTED_NAME]}"
                    eval "$VAR=true"
                fi
            done <<< "$SELECTED"
        fi
    else
        echo -e "${COLOR_BLUE:-}${HEADER}${COLOR_RESET:-}"
        echo
        local I=1
        for NAME in "${PLUGIN_NAMES[@]}"; do
            echo -e "${COLOR_BLUE:-}${I}) ${NAME} - ${PLUGIN_DESCRIPTION[$NAME]}${COLOR_RESET:-}"
            I=$((I + 1))
        done
        echo
        local PROMPT_TEXT
        if type t &>/dev/null; then
            PROMPT_TEXT="$(t MSG_PLUGIN_ENTER_NUMBERS)"
        else
            PROMPT_TEXT="Enter plugin numbers (space-separated):"
        fi
        printf "${COLOR_GOLD:-}${PROMPT_TEXT} ${COLOR_RESET:-}"
        read -r PLUGIN_CHOICES

        # Clear the menu
        local LINES_TO_CLEAR=$((${#PLUGIN_NAMES[@]} + 3))
        tput cuu "$LINES_TO_CLEAR" 2>/dev/null
        tput ed 2>/dev/null

        for CHOICE in $PLUGIN_CHOICES; do
            local IDX=$((CHOICE - 1))
            if [ "$IDX" -ge 0 ] && [ "$IDX" -lt "${#PLUGIN_NAMES[@]}" ]; then
                local SELECTED_NAME="${PLUGIN_NAMES[$IDX]}"
                PLUGIN_ENABLED["$SELECTED_NAME"]=true
                local VAR="${PLUGIN_CHOICE_VAR[$SELECTED_NAME]}"
                eval "$VAR=true"
            fi
        done
    fi
}

#------------------------------------------------------------------------------
# CHECK AND RESOLVE PLUGIN DEPENDENCIES
# Auto-enables missing dependencies
#------------------------------------------------------------------------------
check_plugin_dependencies() {
    local CHANGED=true
    while $CHANGED; do
        CHANGED=false
        local NAME
        for NAME in "${!PLUGIN_REGISTRY[@]}"; do
            if [ "${PLUGIN_ENABLED[$NAME]}" != "true" ]; then
                continue
            fi
            local DEPS="${PLUGIN_DEPENDENCIES[$NAME]}"
            if [ -z "$DEPS" ]; then
                continue
            fi
            local DEP
            for DEP in $DEPS; do
                if [ "${PLUGIN_REGISTRY[$DEP]+x}" ] && [ "${PLUGIN_ENABLED[$DEP]}" != "true" ]; then
                    PLUGIN_ENABLED["$DEP"]=true
                    local VAR="${PLUGIN_CHOICE_VAR[$DEP]}"
                    eval "$VAR=true"
                    CHANGED=true
                    if type info_msg &>/dev/null; then
                        local MSG
                        if type t &>/dev/null; then
                            MSG="$(t MSG_PLUGIN_AUTO_DEPENDENCY) $DEP ($(t MSG_PLUGIN_REQUIRED_BY) $NAME)"
                        else
                            MSG="Auto-enabling dependency: $DEP (required by $NAME)"
                        fi
                        info_msg "$MSG"
                    fi
                fi
            done
        done
    done
}

#------------------------------------------------------------------------------
# EXECUTE A SINGLE PLUGIN
# Sources install.sh from the plugin directory
#------------------------------------------------------------------------------
execute_plugin() {
    local NAME="$1"

    if [ "${PLUGIN_ENABLED[$NAME]}" != "true" ]; then
        return 0
    fi

    local INSTALL_SCRIPT="$PLUGINS_DIR/$NAME/install.sh"
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo "Warning: Plugin '$NAME' has no install.sh" >&2
        return 1
    fi

    run_hook "pre_plugin_${NAME}"

    if type title_msg &>/dev/null; then
        local TITLE
        if type t &>/dev/null; then
            TITLE="$(t MSG_PLUGIN_INSTALLING) ${NAME}"
        else
            TITLE="Installing plugin: ${NAME}"
        fi
        title_msg "$TITLE"
    fi

    source "$INSTALL_SCRIPT"

    run_hook "post_plugin_${NAME}"
}

# Execute all enabled plugins in resolved order
execute_all_plugins() {
    local NAME
    for NAME in "${PLUGIN_ORDER[@]}"; do
        execute_plugin "$NAME"
    done
}

#------------------------------------------------------------------------------
# ENABLE ALL PLUGINS (for --full mode)
#------------------------------------------------------------------------------
enable_all_plugins() {
    local NAME
    for NAME in "${!PLUGIN_REGISTRY[@]}"; do
        PLUGIN_ENABLED["$NAME"]=true
        local VAR="${PLUGIN_CHOICE_VAR[$NAME]}"
        eval "$VAR=true"
    done
}

#------------------------------------------------------------------------------
# INIT PLUGIN SYSTEM
# Main entry point: discover manifests + resolve order
#------------------------------------------------------------------------------
init_plugin_system() {
    discover_plugins
    resolve_plugin_order
}
