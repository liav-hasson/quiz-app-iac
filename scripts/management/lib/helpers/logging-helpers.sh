#!/bin/bash
# logging-helpers.sh
# Logging utility functions for manage-project.sh
# This file is sourced by manage-project.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


# Internal logging helpers ----------------------------------------------------

__log_context() {
    local depth=${1:-1}
    local context="main"
    if [[ ${#FUNCNAME[@]} -gt depth ]]; then
        context="${FUNCNAME[$depth]}"
        [[ -z "$context" ]] && context="main"
    fi
    echo "$context"
}

__log_write() {
    local target="$1"
    local context="$2"
    shift 2
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local line="[$timestamp] [$context] $*"
    echo "$line" >> "$target"
    if [[ "$target" != "$MAIN_LOG_FILE" ]]; then
        echo "$line" >> "$MAIN_LOG_FILE"
    fi
}

# Public logging API ----------------------------------------------------------

log_message() {
    local message="$1"
    local target="${2:-$MAIN_LOG_FILE}"
    local context="$( __log_context 2 )"
    __log_write "$target" "$context" "$message"
}

log() {
    log_message "$1" "${2:-$MAIN_LOG_FILE}"
}

log_info() {
    log_message "$1" "${2:-$MAIN_LOG_FILE}"
}

log_warning() {
    log_message "WARNING: $1" "${2:-$MAIN_LOG_FILE}"
}

log_error() {
    log_message "ERROR: $1" "${2:-$MAIN_LOG_FILE}"
}

log_success() {
    log_message "SUCCESS: $1" "${2:-$MAIN_LOG_FILE}"
}

log_terraform() {
    log_message "$1" "$TERRAFORM_LOG_FILE"
}

log_helm() {
    log_message "$1" "$HELM_LOG_FILE"
}

log_argocd() {
    log_message "$1" "$ARGOCD_LOG_FILE"
}

log_bootstrap() {
    log_message "$1" "$BOOTSTRAP_LOG_FILE"
}

run_logged() {
    local log_file="$1"
    shift
    local context="$( __log_context 2 )"
    __log_write "$log_file" "$context" "COMMAND START: $*"

    if "$@" > >(while IFS= read -r line; do __log_write "$log_file" "$context" "$line"; done) \
              2> >(while IFS= read -r line; do __log_write "$log_file" "$context" "$line"; done); then
        __log_write "$log_file" "$context" "COMMAND END (exit 0)"
        return 0
    else
        local exit_code=$?
        __log_write "$log_file" "$context" "COMMAND END (exit $exit_code)"
        return "$exit_code"
    fi
}

run_logged_silent() {
    local log_file="$1"
    shift
    local context="$( __log_context 2 )"
    __log_write "$log_file" "$context" "COMMAND START: $*"
    if "$@" > >(while IFS= read -r line; do __log_write "$log_file" "$context" "$line"; done) \
            2> >(while IFS= read -r line; do __log_write "$log_file" "$context" "$line"; done); then
        __log_write "$log_file" "$context" "COMMAND END (exit 0)"
        return 0
    else
        local exit_code=$?
        __log_write "$log_file" "$context" "COMMAND END (exit $exit_code)"
        return "$exit_code"
    fi
}

print_log_locations() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}      📂 Log locations${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo "Log directory: $LOG_DIR"
    echo "  Main log:       $(basename "$MAIN_LOG_FILE")"
    echo "  Terraform log:  $(basename "$TERRAFORM_LOG_FILE")"
    echo "  Helm log:       $(basename "$HELM_LOG_FILE")"
    echo "  ArgoCD log:     $(basename "$ARGOCD_LOG_FILE")"
    echo "  Bootstrap log:  $(basename "$BOOTSTRAP_LOG_FILE")"
    echo ""
    echo -e "${BLUE}👉 Use 'monitor-deployment' to tail logs.${NC}"
    echo ""
}

  