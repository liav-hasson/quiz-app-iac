#!/bin/bash

# Notification Helper Script for manage-project.sh
#
# Called by manage-project.sh:
#   - At beginning: "./notify-status.sh start apply"
#   - At end: "./notify-status.sh end apply 0" (success) or 
# "./notify-status.sh end apply 1 kubespray" (failure)

set -euo pipefail

# Parse arguments
MODE="${1:-help}"
OPERATION="${2:-}"
EXIT_CODE="${3:-}"
FAILED_STEP="${4:-}"

# State file to persist start time between calls
STATE_FILE="/tmp/manage-project-state.env"

# Self-contained path handling (no central config needed for quiz-app)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root (workspace) is four levels up from lib/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"

# Load webhook from SSM Parameter Store directly (no central-config.yaml needed)
SLACK_WEBHOOK=""

# Slack webhook is stored in AWS SSM Parameter Store
SLACK_WEBHOOK=$(aws ssm get-parameter --name "/quiz-app/slack-webhook-url" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Helper functions
show_help() {
    echo ""
    echo "🛠️  Notification Helper Script for manage-project.sh"
    echo "=================================================="
    echo ""
    echo "Usage: notify-status.sh <mode> <operation> [exit_code] [failed_step]"
    echo ""
    echo "Modes:"
    echo "  start <operation>                    Save start time for operation (apply/destroy)"
    echo "  end <operation> <exit_code> [step]   Send notification with results"
    echo ""
    echo "Examples:"
    echo "  notify-status.sh start apply         # Called at beginning"
    echo "  notify-status.sh end apply 0         # Success"
    echo "  notify-status.sh end apply 1 kubespray  # Failed at kubespray step"
    echo ""
}

start_operation() {
    local operation="$1"
    local start_time=$(date +%s)
    local start_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Save state for end operation
    cat > "$STATE_FILE" << EOF
START_TIME=$start_time
START_TIMESTAMP="$start_timestamp"
OPERATION=$operation
EOF
    
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] Starting $operation operation...${NC}"
    
    # Send start notification to Slack if webhook configured
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local operation_display message
        if [[ "$operation" == "apply" ]]; then
            operation_display="Deployment"
            message="Infrastructure provisioning started (Terraform + Kubespray)\n\n_Application deployments will be handled by ArgoCD_"
        else
            operation_display="Destruction"
            message="Infrastructure teardown started\n\n_GitLab AMI backup will be created_"
        fi
        
        send_slack_notification "🚀 WeatherLabs Infrastructure $operation_display Started" \
            "$message\n\nStarted: $start_timestamp" \
            "#FFA500"  # Orange
    fi
}

end_operation() {
    local operation="$1"
    local exit_code="$2"
    local failed_step="${3:-}"
    
    # Load start state
    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}[ERROR] State file not found. Must call 'start' mode first.${NC}" >&2
        exit 1
    fi
    
    source "$STATE_FILE"
    
    local end_time=$(date +%s)
    local end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local duration=$((end_time - START_TIME))
    local duration_formatted=$(printf "%02d:%02d:%02d" $((duration/3600)) $(((duration%3600)/60)) $((duration%60)))
    
    # Determine success/failure
    local status_icon status_text color
    if [[ "$exit_code" == "0" ]]; then
        status_icon="✅"
        status_text="SUCCESS"
        color="#00FF00"  # Green
        echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $operation completed successfully in ${duration_formatted}${NC}"
    else
        status_icon="❌"
        status_text="FAILED"
        color="#FF0000"  # Red
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $operation failed after ${duration_formatted}${NC}"
        if [[ -n "$failed_step" ]]; then
            echo -e "${RED}Failed step: $failed_step${NC}"
        fi
    fi
    
    # Send end notification to Slack if webhook configured
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local operation_display message
        if [[ "$operation" == "apply" ]]; then
            operation_display="Deployment"
            if [[ "$exit_code" == "0" ]]; then
                message="Infrastructure provisioning completed successfully (VPC, EC2, EKS, Kubespray)\n\n_ArgoCD is now watching Git and will auto-deploy applications_"
            else
                message="Infrastructure provisioning failed"
                if [[ -n "$failed_step" ]]; then
                    message="$message at step: $failed_step"
                fi
            fi
        else
            operation_display="Destruction"
            if [[ "$exit_code" == "0" ]]; then
                message="Infrastructure teardown completed successfully\n\n_All resources have been destroyed_"
            else
                message="Infrastructure teardown failed"
                if [[ -n "$failed_step" ]]; then
                    message="$message at step: $failed_step"
                fi
            fi
        fi
        
        send_slack_notification "$status_icon WeatherLabs Infrastructure $operation_display $status_text" \
            "$message\n\nDuration: $duration_formatted\nCompleted: $end_timestamp" \
            "$color"
    fi
    
    # Clean up state file
    rm -f "$STATE_FILE"
}

send_slack_notification() {
    local title="$1"
    local message="$2"
    local color="$3"
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        echo -e "${YELLOW}[WARN] Slack webhook not configured, skipping notification${NC}"
        return 0
    fi
    
    local payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "$title",
            "text": "$message",
            "footer": "WeatherLabs Infrastructure",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    if curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK" >/dev/null; then
        echo -e "${GREEN}[INFO] Slack notification sent${NC}"
    else
        echo -e "${YELLOW}[WARN] Failed to send Slack notification${NC}"
    fi
}

# Main script logic
case "$MODE" in
    "start")
        if [[ -z "$OPERATION" ]]; then
            echo -e "${RED}[ERROR] Operation required for start mode${NC}" >&2
            echo "Usage: $0 start <operation>" >&2
            exit 1
        fi
        
        if [[ "$OPERATION" != "apply" && "$OPERATION" != "destroy" ]]; then
            echo -e "${RED}[ERROR] Operation must be 'apply' or 'destroy'${NC}" >&2
            exit 1
        fi
        
        start_operation "$OPERATION"
        ;;
        
    "end")
        if [[ -z "$OPERATION" || -z "$EXIT_CODE" ]]; then
            echo -e "${RED}[ERROR] Operation and exit code required for end mode${NC}" >&2
            echo "Usage: $0 end <operation> <exit_code> [failed_step]" >&2
            exit 1
        fi
        
        if [[ "$OPERATION" != "apply" && "$OPERATION" != "destroy" ]]; then
            echo -e "${RED}[ERROR] Operation must be 'apply' or 'destroy'${NC}" >&2
            exit 1
        fi
        
        if [[ ! "$EXIT_CODE" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}[ERROR] Exit code must be a number${NC}" >&2
            exit 1
        fi
        
        end_operation "$OPERATION" "$EXIT_CODE" "$FAILED_STEP"
        ;;
        
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
        
    *)
        echo -e "${RED}[ERROR] Invalid mode: $MODE${NC}" >&2
        echo "Usage: $0 {start|end|help}" >&2
        show_help
        exit 1
        ;;
esac