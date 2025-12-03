#!/bin/bash

# =============================================================================
# Internationalization library for OhMyTermux
# =============================================================================

# Global variables
SUPPORTED_LANGUAGES=("en" "fr")
DEFAULT_LANGUAGE="en"
CURRENT_LANGUAGE=""
MESSAGES_LOADED=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Performance cache
declare -A TRANSLATION_CACHE
declare -A MISSING_KEYS_LOGGED
CACHE_ENABLED=true
LAZY_LOADING=true

# =============================================================================
# Automatic language detection
# =============================================================================

# Extracts the language code from the system locale
extract_language_from_locale() {
    local locale_var=""
    
    # Priority: LANG > LC_ALL > LANGUAGE
    if [ -n "$LANG" ]; then
        locale_var="$LANG"
    elif [ -n "$LC_ALL" ]; then
        locale_var="$LC_ALL"
    elif [ -n "$LANGUAGE" ]; then
        locale_var="$LANGUAGE"
    fi
    
    # Extract language code (e.g. fr_FR.UTF-8 -> fr)
    if [ -n "$locale_var" ]; then
        echo "${locale_var%%_*}" | tr '[:upper:]' '[:lower:]'
    else
        echo "$DEFAULT_LANGUAGE"
    fi
}

# Checks if a language is supported
is_language_supported() {
    local lang="$1"
    local supported_lang
    
    for supported_lang in "${SUPPORTED_LANGUAGES[@]}"; do
        if [ "$lang" = "$supported_lang" ]; then
            return 0
        fi
    done
    return 1
}

# Automatic language detection with priorities
detect_language() {
    local lang=""
    
    # Priority 1: --lang parameter or OVERRIDE_LANG variable
    if [ -n "$OVERRIDE_LANG" ]; then
        lang="$OVERRIDE_LANG"
    # Priority 2: OHMYTERMUX_LANG environment variable
    elif [ -n "$OHMYTERMUX_LANG" ]; then
        lang="$OHMYTERMUX_LANG"
    # Priority 3: detect from system locale
    else
        lang=$(extract_language_from_locale)
    fi
    
    # Validate supported language
    if is_language_supported "$lang"; then
        echo "$lang"
    else
        # Warning if language not supported
        if [ -n "$lang" ] && [ "$lang" != "$DEFAULT_LANGUAGE" ]; then
            echo "Warning: Language '$lang' not supported. Using default English." >&2
        fi
        echo "$DEFAULT_LANGUAGE"
    fi
}

# =============================================================================
# Message loading
# =============================================================================

# Loads message files for a given language
load_messages() {
    local language="$1"
    local messages_file="$SCRIPT_DIR/messages/${language}.sh"
    
    if [ -f "$messages_file" ]; then
        # Load the message file
        source "$messages_file"
        CURRENT_LANGUAGE="$language"
        MESSAGES_LOADED=true
        return 0
    else
        # Fallback to English if file does not exist
        local fallback_file="$SCRIPT_DIR/messages/$DEFAULT_LANGUAGE.sh"
        if [ -f "$fallback_file" ] && [ "$language" != "$DEFAULT_LANGUAGE" ]; then
            echo "Warning: Message file '$messages_file' not found. Using English." >&2
            source "$fallback_file"
            CURRENT_LANGUAGE="$DEFAULT_LANGUAGE"
            MESSAGES_LOADED=true
            return 1
        else
            echo "Error: Unable to load messages for language '$language'." >&2
            MESSAGES_LOADED=false
            return 2
        fi
    fi
}

# =============================================================================
# Main translation function
# =============================================================================

# Optimized main translation function
t() {
    local key="$1"
    local default="$2"

    # Lazy loading: initialize if needed
    if [ "$LAZY_LOADING" = "true" ] && [ "$MESSAGES_LOADED" != "true" ]; then
        init_i18n >/dev/null 2>&1
    fi

    # Quick check if messages are loaded
    if [ "$MESSAGES_LOADED" != "true" ]; then
        echo "${default:-$key}"
        return 1
    fi

    # Quick check for empty key
    if [ -z "$key" ]; then
        echo "${default:-$key}"
        return 0
    fi

    # Cache hit: check cache first
    local cache_key="${CURRENT_LANGUAGE}:${key}"
    if [ "$CACHE_ENABLED" = "true" ] && [ -n "${TRANSLATION_CACHE[$cache_key]}" ]; then
        echo "${TRANSLATION_CACHE[$cache_key]}"
        return 0
    fi

    # Retrieve translation via indirect reference
    local translation="${!key}"

    if [ -n "$translation" ]; then
        # Cache the translation
        [ "$CACHE_ENABLED" = "true" ] && TRANSLATION_CACHE[$cache_key]="$translation"
        echo "$translation"
    elif [ -n "$default" ]; then
        # Cache the default
        [ "$CACHE_ENABLED" = "true" ] && TRANSLATION_CACHE[$cache_key]="$default"
        echo "$default"
        log_missing_translation_optimized "$key"
    else
        # Cache the key as fallback
        [ "$CACHE_ENABLED" = "true" ] && TRANSLATION_CACHE[$cache_key]="$key"
        echo "$key"
        log_missing_translation_optimized "$key"
    fi
}

# =============================================================================
# Logging of missing translations
# =============================================================================

# Logs missing translations to a log file (optimized)
log_missing_translation_optimized() {
    local key="$1"

    # In-memory check for already logged keys (avoids disk access)
    local missing_key="${CURRENT_LANGUAGE}:${key}"
    if [ -n "${MISSING_KEYS_LOGGED[$missing_key]}" ]; then
        return 0
    fi

    # Mark as logged in memory
    MISSING_KEYS_LOGGED[$missing_key]=1

    local log_dir="$HOME/.config/OhMyTermux"
    local log_file="$log_dir/i18n.log"

    # Create log directory if needed
    [ ! -d "$log_dir" ] && mkdir -p "$log_dir"

    # Log the missing translation (no file check)
    echo "[$(date +'%d/%m/%Y %H:%M:%S')] MISSING_TRANSLATION: $key | Language: $CURRENT_LANGUAGE" >> "$log_file"
}

# Compatible version of the original function
log_missing_translation() {
    log_missing_translation_optimized "$1"
}

# =============================================================================
# i18n system initialization
# =============================================================================

# Initializes the internationalization system
init_i18n() {
    local requested_lang="$1"
    local detected_lang
    
    # Use requested language or detect automatically
    if [ -n "$requested_lang" ]; then
        OVERRIDE_LANG="$requested_lang"
    fi
    
    detected_lang=$(detect_language)
    
    # Load messages
    if load_messages "$detected_lang"; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Utility functions and performance optimization
# =============================================================================

# Displays supported languages
list_supported_languages() {
    echo "Supported languages:"
    local lang
    for lang in "${SUPPORTED_LANGUAGES[@]}"; do
        if [ "$lang" = "$CURRENT_LANGUAGE" ]; then
            echo "  * $lang (current)"
        else
            echo "    $lang"
        fi
    done
}

# Clears the translation cache
clear_translation_cache() {
    TRANSLATION_CACHE=()
    MISSING_KEYS_LOGGED=()
    echo "Translation cache cleared."
}

# Displays cache statistics
show_cache_stats() {
    local cache_size=${#TRANSLATION_CACHE[@]}
    local missing_logged=${#MISSING_KEYS_LOGGED[@]}

    echo "=== i18n cache statistics ==="
    echo "Cached translations: $cache_size"
    echo "Missing keys logged: $missing_logged"
    echo "Cache enabled: $CACHE_ENABLED"
    echo "Lazy loading: $LAZY_LOADING"
    echo "============================"
}

# Enables/disables cache for performance
toggle_cache() {
    if [ "$CACHE_ENABLED" = "true" ]; then
        CACHE_ENABLED=false
        echo "Cache disabled."
    else
        CACHE_ENABLED=true
        echo "Cache enabled."
    fi
}

# Enables/disables lazy loading
toggle_lazy_loading() {
    if [ "$LAZY_LOADING" = "true" ]; then
        LAZY_LOADING=false
        echo "Lazy loading disabled."
    else
        LAZY_LOADING=true
        echo "Lazy loading enabled."
    fi
}

# Preloads current translations into the cache
preload_translations() {
    if [ "$MESSAGES_LOADED" != "true" ]; then
        echo "Error: Messages not loaded."
        return 1
    fi

    local preloaded=0
    local var_name

    # Preload common MSG_* variables
    for var_name in $(compgen -v MSG_); do
        local cache_key="${CURRENT_LANGUAGE}:${var_name}"
        local value="${!var_name}"
        if [ -n "$value" ] && [ -z "${TRANSLATION_CACHE[$cache_key]}" ]; then
            TRANSLATION_CACHE[$cache_key]="$value"
            ((preloaded++))
        fi
    done

    echo "Preload: $preloaded translations added to cache."
}

# Displays extended debug information
debug_i18n() {
    echo "=== i18n debug information ==="
    echo "Current language: $CURRENT_LANGUAGE"
    echo "Messages loaded: $MESSAGES_LOADED"
    echo "Supported languages: ${SUPPORTED_LANGUAGES[*]}"
    echo "LANG: ${LANG:-not set}"
    echo "LC_ALL: ${LC_ALL:-not set}"
    echo "LANGUAGE: ${LANGUAGE:-not set}"
    echo "OHMYTERMUX_LANG: ${OHMYTERMUX_LANG:-not set}"
    echo "OVERRIDE_LANG: ${OVERRIDE_LANG:-not set}"
    echo ""
    show_cache_stats
    echo "============================"
}