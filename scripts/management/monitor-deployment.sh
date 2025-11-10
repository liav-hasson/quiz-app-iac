#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$SCRIPT_DIR/lib/helpers/config-loader.sh"
source "$SCRIPT_DIR/lib/monitor/utilities.sh"

declare -A LOG_FILES=(
    ["main"]="$MAIN_LOG_FILE"
    ["terraform"]="$TERRAFORM_LOG_FILE"
    ["bootstrap"]="$BOOTSTRAP_LOG_FILE"
    ["helm"]="$HELM_LOG_FILE"
    ["argocd"]="$ARGOCD_LOG_FILE"
)

declare -A LOG_DESCRIPTIONS=(
    ["main"]="Main Orchestrator"
    ["terraform"]="Terraform Operations"
    ["bootstrap"]="Bootstrap Scripts"
    ["helm"]="Helm Deployments"
    ["argocd"]="ArgoCD Updates"
)

LOG_SEQUENCE=("main" "terraform" "bootstrap" "helm" "argocd")

main() {
    local action="follow"
    local follow_filter=false
    local tail_lines=20

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -s|--status) action="status"; shift ;;
            -c|--clear) action="clear"; shift ;;
            -f|--filter) action="follow"; follow_filter=true; shift ;;
            -t|--tail)
                action="tail"
                tail_lines="${2:-20}"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    case "$action" in
        status) show_status ;;
        clear) clear_logs ;;
        tail) tail_logs "$tail_lines" ;;
        follow) follow_logs "$follow_filter" ;;
    esac
}

main "$@"
