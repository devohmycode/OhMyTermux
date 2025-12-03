#!/bin/bash

# =============================================================================
# Automatic language detection for OhMyTermux
# =============================================================================

# Languages supported by the system
declare -a SUPPORTED_LANGUAGES=("en" "fr")
DEFAULT_LANGUAGE="en"

# =============================================================================
# Function: extract_language_from_locale
# Description: Extracts the language code from system locale variables
# =============================================================================
extract_language_from_locale() {
    local locale_var=""
    
    # Priority: LC_ALL > LANG > LANGUAGE (LC_ALL has the highest priority)
    if [ -n "$LC_ALL" ]; then
        locale_var="$LC_ALL"
    elif [ -n "$LANG" ]; then
        locale_var="$LANG"
    elif [ -n "$LANGUAGE" ]; then
        locale_var="$LANGUAGE"
    fi
    
    # Extract language code
    if [ -n "$locale_var" ]; then
        # For LANGUAGE, take only the first code before ':'
        if [ "$locale_var" = "$LANGUAGE" ] && [[ "$locale_var" == *":"* ]]; then
            locale_var=$(echo "$locale_var" | cut -d':' -f1)
        fi
        # Extract language code (first 2 characters before _ or .)
        echo "$locale_var" | cut -d'_' -f1 | cut -d'.' -f1 | tr '[:upper:]' '[:lower:]'
    else
        echo "$DEFAULT_LANGUAGE"
    fi
}

# =============================================================================
# Function: is_language_supported
# Description: Checks if a language is supported by the system
# Parameters: $1 - Language code to check
# Return: 0 if supported, 1 otherwise
# =============================================================================
is_language_supported() {
    local lang="$1"
    
    if [ -z "$lang" ]; then
        return 1
    fi
    
    for supported_lang in "${SUPPORTED_LANGUAGES[@]}"; do
        if [ "$lang" = "$supported_lang" ]; then
            return 0
        fi
    done
    
    return 1
}

# =============================================================================
# Function: detect_language
# Description: Detects the language to use according to priority logic
# Priority: --lang parameter > OHMYTERMUX_LANG variable > system locale
# Return: Detected language code (always valid)
# =============================================================================
detect_language() {
    local detected_lang=""
    
    # Priority 1: --lang parameter (stored in OVERRIDE_LANG)
    if [ -n "$OVERRIDE_LANG" ]; then
        detected_lang="$OVERRIDE_LANG"
        if is_language_supported "$detected_lang"; then
            echo "$detected_lang"
            return 0
        else
            log_language_warning "Specified language not supported: $detected_lang"
        fi
    fi
    
    # Priority 2: OHMYTERMUX_LANG environment variable
    if [ -n "$OHMYTERMUX_LANG" ]; then
        detected_lang="$OHMYTERMUX_LANG"
        if is_language_supported "$detected_lang"; then
            echo "$detected_lang"
            return 0
        else
            log_language_warning "Environment language not supported: $detected_lang"
        fi
    fi
    
    # Priority 3: System locale detection
    detected_lang=$(extract_language_from_locale)
    if is_language_supported "$detected_lang"; then
        echo "$detected_lang"
        return 0
    fi
    
    # Fallback: Default language
    echo "$DEFAULT_LANGUAGE"
}

# =============================================================================
# Function: validate_language_parameter
# Description: Validates and normalizes a language parameter
# Parameters: $1 - Language code to validate
# Return: Normalized language code or empty if invalid
# =============================================================================
validate_language_parameter() {
    local lang="$1"
    
    if [ -z "$lang" ]; then
        return 1
    fi
    
    # Normalization: convert to lowercase
    lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
    
    if is_language_supported "$lang"; then
        echo "$lang"
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Function: get_supported_languages
# Description: Returns the list of supported languages
# =============================================================================
get_supported_languages() {
    printf '%s\n' "${SUPPORTED_LANGUAGES[@]}"
}

# =============================================================================
# Function: log_language_warning
# Description: Logs a warning about language detection
# Parameters: $1 - Warning message
# =============================================================================
log_language_warning() {
    local message="$1"
    local log_file="$HOME/.config/OhMyTermux/i18n.log"
    
    # Create log directory if needed
    mkdir -p "$(dirname "$log_file")"
    
    echo "[$(date +'%d/%m/%Y %H:%M:%S')] LANGUAGE_WARNING: $message" >> "$log_file"
    
    # Display warning to user
    echo "⚠️  Warning: $message. Using default English." >&2
}

# =============================================================================
# Function: show_language_help
# Description: Displays help for language selection
# =============================================================================
show_language_help() {
    echo "Supported languages:"
    for lang in "${SUPPORTED_LANGUAGES[@]}"; do
        case "$lang" in
            "en") echo "  - en : English" ;;
            "fr") echo "  - fr : French" ;;
            *) echo "  - $lang" ;;
        esac
    done
    echo ""
    echo "Usage:"
    echo "  --lang <code>           Set the language for this session"
    echo "  export OHMYTERMUX_LANG=<code>  Set the default language"
}