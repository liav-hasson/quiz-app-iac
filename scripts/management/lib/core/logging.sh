#!/bin/bash
# logging.sh
# Unified logging system for all scripts.
# Provides consistent logging to file and console output.
#
# Design:
# - Single log file (no dual-write)
# - Timestamps in log file only, not console
# - Function context preserved in log file for debugging
# - No emojis, colors allowed

# Guard against double-loading
[[ -n "${_LOGGING_LOADED:-}" ]] && return 0
_LOGGING_LOADED=1

# Ensure colors are available
source "${BASH_SOURCE%/*}/colors.sh"

# Ensure paths are available (for LOG_FILE)
source "${BASH_SOURCE%/*}/paths.sh"

# =============================================================================
# Internal Helpers
# =============================================================================

# Get the calling function name for log context
__get_context() {
    local depth="${1:-2}"
    local context="main"
    if [[ ${#FUNCNAME[@]} -gt $depth ]]; then
        context="${FUNCNAME[$depth]}"
        [[ -z "$context" || "$context" == "main" || "$context" == "source" ]] && context="main"
    fi
    echo "$context"
}

# Write to log file (internal)
__write_log() {
    local level="$1"
    local message="$2"
    local context
    context="$(__get_context 3)"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "[$timestamp] [$context] [$level] $message" >> "$LOG_FILE"
}

# =============================================================================
# Public Logging API
# =============================================================================

# Log informational message
# Usage: log_info "message"
log_info() {
    local message="$1"
    __write_log "INFO" "$message"
    echo -e "${BLUE}[INFO]${NC} $message"
}

# Log success message
# Usage: log_success "message"
log_success() {
    local message="$1"
    __write_log "SUCCESS" "$message"
    echo -e "${GREEN}[OK]${NC} $message"
}

# Log warning message
# Usage: log_warning "message"
log_warning() {
    local message="$1"
    __write_log "WARNING" "$message"
    echo -e "${YELLOW}[WARN]${NC} $message"
}

# Log error message
# Usage: log_error "message"
log_error() {
    local message="$1"
    __write_log "ERROR" "$message"
    echo -e "${RED}[ERROR]${NC} $message" >&2
}

# Log step/section header (for major workflow steps)
# Usage: log_step "Starting Terraform"
log_step() {
    local message="$1"
    __write_log "STEP" "$message"
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${WHITE}  $message${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

# Log debug message (only to file, not console)
# Usage: log_debug "detailed info"
log_debug() {
    local message="$1"
    __write_log "DEBUG" "$message"
}

# Log to file only (silent, no console output)
# Usage: log_silent "message"
log_silent() {
    local message="$1"
    __write_log "INFO" "$message"
}

# =============================================================================
# Command Execution with Logging
# =============================================================================

# Run a command and log its output to file
# Console shows only success/failure summary
# Usage: run_logged "description" command arg1 arg2
run_logged() {
    local description="$1"
    shift
    local context
    context="$(__get_context 2)"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Log command start
    echo "[$timestamp] [$context] [CMD_START] $*" >> "$LOG_FILE"
    
    # Run command, capture output
    local output
    local exit_code
    output=$("$@" 2>&1) && exit_code=0 || exit_code=$?
    
    # Log output line by line
    while IFS= read -r line; do
        echo "[$timestamp] [$context] [OUTPUT] $line" >> "$LOG_FILE"
    done <<< "$output"
    
    # Log command end
    echo "[$timestamp] [$context] [CMD_END] exit_code=$exit_code" >> "$LOG_FILE"
    
    return $exit_code
}

# Run a command with live output to both console and log
# Usage: run_live command arg1 arg2
run_live() {
    local context
    context="$(__get_context 2)"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "[$timestamp] [$context] [CMD_START] $*" >> "$LOG_FILE"
    
    # Run with live output
    "$@" 2>&1 | while IFS= read -r line; do
        echo "[$timestamp] [$context] [OUTPUT] $line" >> "$LOG_FILE"
        echo "$line"
    done
    
    local exit_code=${PIPESTATUS[0]}
    echo "[$timestamp] [$context] [CMD_END] exit_code=$exit_code" >> "$LOG_FILE"
    
    return $exit_code
}

# =============================================================================
# Utility Functions
# =============================================================================

# Print log file location
print_log_location() {
    echo ""
    echo -e "${BLUE}Log file:${NC} $LOG_FILE"
    echo -e "${BLUE}Monitor with:${NC} tail -f $LOG_FILE"
    echo ""
}

# Clear log file
clear_log() {
    > "$LOG_FILE"
    log_info "Log file cleared"
}

# =============================================================================
# Aliases for backward compatibility
# =============================================================================

# These will be removed after full migration
log() { log_info "$1"; }
log_message() { log_info "$1"; }
log_terraform() { log_debug "[terraform] $1"; }
log_helm() { log_debug "[helm] $1"; }
log_argocd() { log_debug "[argocd] $1"; }
log_bootstrap() { log_debug "[bootstrap] $1"; }
