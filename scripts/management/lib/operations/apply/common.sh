#!/bin/bash

set -euo pipefail

SHOULD_PUSH_AFTER_TUNNEL=${SHOULD_PUSH_AFTER_TUNNEL:-false}
GIT_COMMIT_MESSAGE=${GIT_COMMIT_MESSAGE:-""}

apply_tf_output() {
    local key="$1"
    local output
    
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    
    output=$(cd "$TERRAFORM_DIR" && terraform output -raw "$key" 2>/dev/null) || {
        log_warning "Terraform output '$key' not found or terraform not applied"
        echo ""
        return 0
    }
    
    echo "$output"
}

apply_stream_notify() {
    local mode="$1"
    local operation="$2"
    local exit_code="${3:-}"
    local failed_step="${4:-}"
    while IFS= read -r line; do
        [[ -n "$line" ]] && log_message "$line"
    done < <("$LIB_DIR/notify-status.sh" "$mode" "$operation" "$exit_code" "$failed_step")
}

apply_log_summary() {
    log_message "╔════════════════════════════════════════════════════════════════╗"
    log_message "║                    INFRASTRUCTURE DEPLOYED                     ║"
    log_message "╚════════════════════════════════════════════════════════════════╝"
    log_message "✓ AWS Infrastructure provisioned (VPC, NAT, Jenkins EC2, EKS)"
    log_message "✓ Kubectl configured for EKS cluster: $EKS_CLUSTER_NAME"
    log_message "✓ Terraform outputs injected into GitOps manifests"
    log_message "✓ ArgoCD bootstrap deployed to EKS"
    log_message "✓ ArgoCD applications synced (controllers + workloads)"
    log_message ""
    log_message "📋 NEXT STEPS:"
    log_message "   • Monitor ArgoCD sync: kubectl get applications -n argocd"
    log_message "   • Check app status: argocd app list"
    log_message "   • View quiz-app: kubectl get pods -n quiz-app"
    log_message ""
    log_message "Logs available: $LOG_DIR"
}
