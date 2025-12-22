#!/bin/bash
# colors.sh
# Single source of truth for terminal color codes.
# Source this file for consistent colors across all scripts.

# Guard against double-loading
[[ -n "${_COLORS_LOADED:-}" ]] && return 0
_COLORS_LOADED=1

# Standard colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'  # No Color / Reset

# Export for subshells
export RED GREEN YELLOW BLUE PURPLE CYAN WHITE BOLD NC
