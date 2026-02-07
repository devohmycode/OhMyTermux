#!/bin/bash
#------------------------------------------------------------------------------
# PLUGIN: theme-catppuccin
# Installs Catppuccin color theme for Termux terminal
#------------------------------------------------------------------------------

register_plugin \
    --name "theme-catppuccin" \
    --version "1.0.0" \
    --description "Catppuccin color theme for Termux" \
    --cli-flag "--catppuccin" \
    --cli-short "-cat" \
    --priority 80

# Apply theme after initial config is done
plugin_hook "post_initial_config" "theme-catppuccin" "catppuccin_post_config"

catppuccin_post_config() {
    # Theme will be applied during plugin execution (install.sh)
    return 0
}
