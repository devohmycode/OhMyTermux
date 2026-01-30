#!/bin/bash
#------------------------------------------------------------------------------
# COMMON LIBRARY LOADER
# Sources all lib modules in the correct order
#------------------------------------------------------------------------------

# Determine the lib directory
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$_LIB_DIR/colors.sh"
source "$_LIB_DIR/messages.sh"
source "$_LIB_DIR/logging.sh"
source "$_LIB_DIR/execute.sh"
source "$_LIB_DIR/gum_ui.sh"
source "$_LIB_DIR/banner.sh"
