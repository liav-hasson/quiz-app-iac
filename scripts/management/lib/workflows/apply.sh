#!/bin/bash
# workflows/apply.sh
# High-level orchestration for infrastructure deployment.
# Coordinates tasks in the correct order.

# Guard against double-loading
[[ -n "${_WORKFLOW_APPLY_LOADED:-}" ]] && return 0
_WORKFLOW_APPLY_LOADED=1

# Source required tasks
source "$TASKS_DIR/terraform.sh"
source "$TASKS_DIR/inject-values.sh"
source "$TASKS_DIR/git-sync.sh"
source "$TASKS_DIR/argocd.sh"
source "$TASKS_DIR/dns.sh"
source "$HELPERS_DIR/notification.sh"
source "$TOOLS_DIR/preflight-check.sh"

# =============================================================================
# Apply Workflow
# =============================================================================

workflow_apply() {
    local operation="apply"
    
    # Send start notification
    notify_start "$operation"
    
    # Step 1: Preflight checks
    log_step "Preflight Checks"
    if ! run_preflight_check; then
        log_warning "Preflight check had warnings, continuing..."
    fi
    
    # Step 2: Terraform apply
    log_step "Terraform Deployment"
    if ! task_terraform_apply; then
        notify_failure "$operation" "terraform_apply"
        return 1
    fi
    
    # Step 3: Configure kubectl for EKS
    log_step "EKS Cluster Configuration"
    if ! task_configure_eks; then
        notify_failure "$operation" "eks_configure"
        return 1
    fi
    
    # Step 4: Inject Terraform outputs into GitOps manifests
    log_step "Injecting Terraform Values"
    if ! task_inject_terraform_values; then
        notify_failure "$operation" "inject_values"
        return 1
    fi
    
    # Step 5: Commit and push GitOps changes
    log_step "Syncing GitOps Repository"
    if ! task_commit_gitops_changes; then
        notify_failure "$operation" "git_sync"
        return 1
    fi
    
    # Step 6: Deploy ArgoCD
    log_step "Deploying ArgoCD"
    if ! task_bootstrap_argocd; then
        notify_failure "$operation" "argocd_bootstrap"
        return 1
    fi
    
    # Step 7: Deploy ArgoCD applications
    log_step "Deploying Applications"
    if ! task_deploy_argocd_apps; then
        notify_failure "$operation" "argocd_apps"
        return 1
    fi
    
    # Step 8: Update DNS to point to Istio NLB
    log_step "Updating DNS Records"
    if ! task_update_dns; then
        log_warning "DNS update had issues - verify manually"
        # Don't fail the whole workflow for DNS issues
    fi
    
    # Success
    log_step "Deployment Complete"
    workflow_apply_summary
    notify_success "$operation"
    
    return 0
}

workflow_apply_summary() {
    echo ""
    echo "=========================================="
    echo "         INFRASTRUCTURE DEPLOYED         "
    echo "=========================================="
    echo ""
    log_success "AWS Infrastructure provisioned (VPC, NAT, Jenkins EC2, EKS)"
    log_success "Kubectl configured for EKS cluster: $EKS_CLUSTER_NAME"
    log_success "Terraform outputs injected into GitOps manifests"
    log_success "ArgoCD bootstrap deployed to EKS"
    log_success "ArgoCD applications synced"
    echo ""
    log_info "NEXT STEPS:"
    echo "  - Monitor ArgoCD sync: kubectl get applications -n argocd"
    echo "  - Check app status:    argocd app list"
    echo "  - View quiz-app pods:  kubectl get pods -n quiz-app"
    echo ""
    log_info "Log file: $LOG_FILE"
    echo ""
}
