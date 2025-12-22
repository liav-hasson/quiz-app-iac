#!/bin/bash
# helpers/notification.sh
# Slack notification helpers for deployment status

# Guard against double-loading
[[ -n "${_HELPER_NOTIFICATION_LOADED:-}" ]] && return 0
_HELPER_NOTIFICATION_LOADED=1

# =============================================================================
# Configuration
# =============================================================================

# State file for tracking operation timing
_NOTIFY_STATE_FILE="/tmp/manage-project-state.env"

# Load webhook from SSM (cached)
_SLACK_WEBHOOK=""

_load_slack_webhook() {
    if [[ -n "$_SLACK_WEBHOOK" ]]; then
        return 0
    fi
    
    _SLACK_WEBHOOK=$(aws ssm get-parameter \
        --name "/quiz-app/slack-webhook-url" \
        --with-decryption \
        --query 'Parameter.Value' \
        --output text 2>/dev/null || echo "")
}

# =============================================================================
# Public API
# =============================================================================

notify_start() {
    local operation="$1"
    local start_time
    start_time=$(date +%s)
    local start_timestamp
    start_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Save state
    cat > "$_NOTIFY_STATE_FILE" << EOF
START_TIME=$start_time
START_TIMESTAMP="$start_timestamp"
OPERATION=$operation
EOF
    
    log_info "Starting $operation operation"
    
    # Send Slack notification
    _load_slack_webhook
    if [[ -n "$_SLACK_WEBHOOK" ]]; then
        local title message color
        if [[ "$operation" == "apply" ]]; then
            title="Infrastructure Deployment Started"
            message="Infrastructure provisioning started"
        else
            title="Infrastructure Destruction Started"
            message="Infrastructure teardown started (Jenkins AMI backup will be created)"
        fi
        
        _send_slack "$title" "$message\n\nStarted: $start_timestamp" "#FFA500"
    fi
}

notify_success() {
    local operation="$1"
    
    # Load state
    local start_time duration
    if [[ -f "$_NOTIFY_STATE_FILE" ]]; then
        source "$_NOTIFY_STATE_FILE"
        local end_time
        end_time=$(date +%s)
        duration=$((end_time - START_TIME))
    else
        duration=0
    fi
    
    local duration_str
    duration_str=$(_format_duration "$duration")
    
    log_success "$operation completed successfully in $duration_str"
    
    # Send Slack notification
    _load_slack_webhook
    if [[ -n "$_SLACK_WEBHOOK" ]]; then
        local title message
        if [[ "$operation" == "apply" ]]; then
            title="Infrastructure Deployment Successful"
            message="Infrastructure provisioning completed"
        else
            title="Infrastructure Destruction Successful"
            message="Infrastructure teardown completed"
        fi
        
        _send_slack "$title" "$message\n\nDuration: $duration_str" "#36a64f"
    fi
    
    # Cleanup state file
    rm -f "$_NOTIFY_STATE_FILE" 2>/dev/null
}

notify_failure() {
    local operation="$1"
    local failed_step="$2"
    
    # Load state
    local start_time duration
    if [[ -f "$_NOTIFY_STATE_FILE" ]]; then
        source "$_NOTIFY_STATE_FILE"
        local end_time
        end_time=$(date +%s)
        duration=$((end_time - START_TIME))
    else
        duration=0
    fi
    
    local duration_str
    duration_str=$(_format_duration "$duration")
    
    log_error "$operation failed at step: $failed_step (after $duration_str)"
    
    # Send Slack notification
    _load_slack_webhook
    if [[ -n "$_SLACK_WEBHOOK" ]]; then
        local title message
        if [[ "$operation" == "apply" ]]; then
            title="Infrastructure Deployment Failed"
        else
            title="Infrastructure Destruction Failed"
        fi
        message="Failed at step: $failed_step\nDuration: $duration_str\nCheck logs: $LOG_FILE"
        
        _send_slack "$title" "$message" "#ff0000"
    fi
    
    # Keep state file for debugging
}

# =============================================================================
# Internal Helpers
# =============================================================================

_format_duration() {
    local seconds="$1"
    
    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        local mins=$((seconds / 60))
        local secs=$((seconds % 60))
        echo "${mins}m ${secs}s"
    else
        local hours=$((seconds / 3600))
        local mins=$(((seconds % 3600) / 60))
        echo "${hours}h ${mins}m"
    fi
}

_send_slack() {
    local title="$1"
    local message="$2"
    local color="$3"
    
    [[ -z "$_SLACK_WEBHOOK" ]] && return 0
    
    local payload
    payload=$(cat <<EOF
{
    "attachments": [{
        "color": "$color",
        "title": "$title",
        "text": "$message",
        "footer": "Quiz App Infrastructure",
        "ts": $(date +%s)
    }]
}
EOF
)
    
    curl -s -X POST \
        -H 'Content-type: application/json' \
        --data "$payload" \
        "$_SLACK_WEBHOOK" >/dev/null 2>&1 || true
}
