#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log_info()   { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() {
    echo -e "${PURPLE}============================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}============================================${NC}"
}

format_age() {
    local seconds=$1
    if (( seconds < 60 )); then
        printf "%ss" "$seconds"
    elif (( seconds < 3600 )); then
        printf "%sm" $((seconds / 60))
    else
        printf "%sh" $((seconds / 3600))
    fi
}

get_file_status() {
    local file=$1
    if [[ ! -e "$file" ]]; then
        echo "NOT_FOUND"
        return
    fi
    if [[ ! -s "$file" ]]; then
        echo "EMPTY"
        return
    fi
    local now=$(date +%s)
    local mtime
    mtime=$(stat -c %Y "$file")
    local age=$((now - mtime))
    if (( age <= 60 )); then
        echo "ACTIVE"
    elif (( age <= 300 )); then
        echo "STALE"
    else
        echo "IDLE"
    fi
}

print_status() {
    case "$1" in
        ACTIVE) echo -e "  ${GREEN}Status: ACTIVE${NC}" ;;
        STALE)  echo -e "  ${YELLOW}Status: STALE${NC}" ;;
        IDLE)   echo -e "  ${CYAN}Status: IDLE${NC}" ;;
        EMPTY)  echo -e "  ${YELLOW}Status: EMPTY${NC}" ;;
        NOT_FOUND) echo -e "  ${RED}Status: NOT FOUND${NC}" ;;
    esac
}

colorize_line() {
    local line=$1
    if [[ "$line" =~ ERROR|FAILED|Exception ]]; then
        echo -e "${RED}${line}${NC}"
    elif [[ "$line" =~ WARNING|WARN|⚠️ ]]; then
        echo -e "${YELLOW}${line}${NC}"
    elif [[ "$line" =~ SUCCESS|COMPLETED|✅ ]]; then
        echo -e "${GREEN}${line}${NC}"
    elif [[ "$line" =~ INFO|STEP|TASK|PLAY ]]; then
        echo -e "${BLUE}${line}${NC}"
    else
        echo "$line"
    fi
}

show_help() {
        echo -e ""
        echo -e "${WHITE}🖥️  Quiz-App Deployment Monitor${NC}"
        echo -e "${PURPLE}=================================${NC}"
        echo -e ""
        echo -e "${WHITE}Usage:${NC} monitor-deployment.sh [options]"
        echo -e ""
        echo -e "${WHITE}Options:${NC}"
        echo -e "  -h, --help          Show this help and exit"
        echo -e "  -s, --status        Summarise log files for the current bundle"
        echo -e "  -t, --tail <N>      Display the last N lines from each log (default 20)"
        echo -e "  -f, --filter        Follow logs in real time and highlight key events only"
        echo -e "  -c, --clear         Remove all log files for the current bundle"
        echo -e ""
        echo -e "${WHITE}Notes:${NC}"
        echo -e "  • Logs are stored under ${LOG_DIR}"
        echo -e "  • Use --filter during deployments for a concise view"
        echo -e ""
}

clear_logs() {
    log_header "Clearing deployment logs"
    local removed_any=false
    for key in "${LOG_SEQUENCE[@]}"; do
        local file="${LOG_FILES[$key]}"
        if [[ -f "$file" ]]; then
            rm -f "$file"
            echo -e "${GREEN}✔ Cleared ${LOG_DESCRIPTIONS[$key]} (${file})${NC}"
            removed_any=true
        else
            echo -e "${YELLOW}• ${LOG_DESCRIPTIONS[$key]} log not found (${file})${NC}"
        fi
    done
    $removed_any || log_warn "No log files found"
}

show_status() {
    log_header "Deployment Log Status"
    echo -e "${CYAN}Log Directory:${NC} $LOG_DIR"
    echo
    for key in "${LOG_SEQUENCE[@]}"; do
        local file="${LOG_FILES[$key]}"
        local description="${LOG_DESCRIPTIONS[$key]}"
        echo -e "${WHITE}${description}:${NC}"
        echo -e "  ${CYAN}File:${NC} $file"
        local status
        status=$(get_file_status "$file")
        print_status "$status"
        if [[ -f "$file" ]]; then
            local size
            size=$(du -h "$file" | cut -f1)
            local modified
            modified=$(stat -c %y "$file" | cut -d. -f1)
            local age=$(( $(date +%s) - $(stat -c %Y "$file") ))
            echo -e "  ${CYAN}Size:${NC} $size  ${CYAN}Modified:${NC} $modified ($(format_age "$age") ago)"
        fi
        echo
    done
}

tail_logs() {
    local lines=${1:-20}
    log_header "Tail (last $lines lines)"
    for key in "${LOG_SEQUENCE[@]}"; do
        local file="${LOG_FILES[$key]}"
        local description="${LOG_DESCRIPTIONS[$key]}"
        echo -e "${CYAN}=== $description ===${NC}"
        if [[ -f "$file" ]]; then
            tail -n "$lines" "$file" || log_warn "Unable to read $file"
        else
            echo -e "${YELLOW}(log file not found)${NC}"
        fi
        echo
    done
}

follow_logs() {
    local filtered=${1:-false}
    log_header "Following deployment logs"
    
    # Build file list based on filter mode
    local -a files_to_follow=()
    
    if [[ "$filtered" == true ]]; then
        log_info "Filter mode enabled: excluding kubespray, showing only custom logs"
        # Exclude kubespray log in filter mode
        for key in "${LOG_SEQUENCE[@]}"; do
            if [[ "$key" != "kubespray" ]]; then
                files_to_follow+=("${LOG_FILES[$key]}")
            fi
        done
    else
        log_info "Showing ALL logs (including kubespray verbose output)"
        # Include all logs
        files_to_follow=("${LOG_FILES[@]}")
    fi
    
    log_info "Press Ctrl+C to stop monitoring"

    for file in "${files_to_follow[@]}"; do
        touch "$file"
    done

    trap 'echo -e "\n${YELLOW}Monitoring stopped.${NC}"; exit 0' INT

    local tail_cmd=(tail -n 0 -F)
    tail_cmd+=("${files_to_follow[@]}")

    set +e
    if [[ "$filtered" == true ]]; then
        # Filter mode: only show important events from non-kubespray logs
        "${tail_cmd[@]}" 2>/dev/null | grep --line-buffered -E "(ERROR|FAILED|WARNING|WARN|Exception|TASK|PLAY|COMPLETED|SUCCESS|✅|⚠️)" | while IFS= read -r line; do
            colorize_line "$line"
        done
    else
        # Unfiltered mode: show all output from all logs
        "${tail_cmd[@]}" 2>/dev/null | while IFS= read -r line; do
            colorize_line "$line"
        done
    fi
    set -e
}
