#!/bin/bash
# init.sh
# Main initialization script for the management system.
# Source this single file to get all core functionality.
#
# Usage (from any script):
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/core/init.sh"
#   OR
#   source "$LIB_DIR/core/init.sh"

# Guard against double-loading
[[ -n "${_INIT_LOADED:-}" ]] && return 0
_INIT_LOADED=1

# Enable strict mode
set -euo pipefail

# =============================================================================
# Resolve core directory (handles being sourced from anywhere)
# =============================================================================

_INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Source core modules in order
# =============================================================================

source "$_INIT_DIR/colors.sh"
source "$_INIT_DIR/paths.sh"
source "$_INIT_DIR/logging.sh"

# =============================================================================
# Error Handling
# =============================================================================

# Global error handler
_error_handler() {
    local exit_code=$?
    local line_no=$1
    local command="${BASH_COMMAND}"
    
    log_error "Command failed at line $line_no: $command (exit code: $exit_code)"
    
    # If we have a cleanup function defined, call it
    if declare -f _cleanup >/dev/null 2>&1; then
        _cleanup
    fi
    
    exit $exit_code
}

# Set up error trap (can be disabled with set +e temporarily)
trap '_error_handler ${LINENO}' ERR

# =============================================================================
# Signal Handling
# =============================================================================

# Handle Ctrl+C gracefully
_interrupt_handler() {
    echo ""
    log_warning "Interrupted by user"
    
    if declare -f _cleanup >/dev/null 2>&1; then
        _cleanup
    fi
    
    exit 130
}

trap '_interrupt_handler' INT TERM

# =============================================================================
# Initialization Complete
# =============================================================================

log_debug "Core initialized from $_INIT_DIR"
