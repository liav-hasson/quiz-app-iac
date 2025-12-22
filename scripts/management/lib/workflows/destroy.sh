#!/bin/bash
# workflows/destroy.sh
# High-level orchestration for infrastructure teardown.
# Coordinates cleanup tasks in the correct order.

# Guard against double-loading
[[ -n "${_WORKFLOW_DESTROY_LOADED:-}" ]] && return 0
_WORKFLOW_DESTROY_LOADED=1

# Source required tasks
source "$TASKS_DIR/jenkins-backup.sh"
source "$TASKS_DIR/eks-cleanup.sh"
source "$TASKS_DIR/terraform.sh"
source "$HELPERS_DIR/notification.sh"

# =============================================================================
# Destroy Workflow
# =============================================================================

workflow_destroy() {
    local operation="destroy"
    
    # Send start notification
    notify_start "$operation"
    
    # Step 1: Backup Jenkins AMI (before destroying infrastructure)
    log_step "Jenkins AMI Backup"
    if ! task_backup_jenkins_ami; then
        log_warning "Jenkins AMI backup failed, continuing with destroy..."
    fi
    
    # Step 2: Cleanup EKS cluster resources (finalizers, NLB, etc.)
    log_step "EKS Cluster Cleanup"
    if ! task_cleanup_eks_cluster; then
        log_warning "EKS cleanup had issues, continuing with Terraform destroy..."
    fi
    
    # Step 3: Terraform destroy
    log_step "Terraform Destruction"
    if ! task_terraform_destroy; then
        notify_failure "$operation" "terraform_destroy"
        return 1
    fi
    
    # Step 4: Cleanup kubectl config
    log_step "Cleanup"
    task_cleanup_kubeconfig
    
    # Success
    log_step "Destruction Complete"
    workflow_destroy_summary
    notify_success "$operation"
    
    return 0
}

workflow_destroy_summary() {
    echo ""
    echo "=========================================="
    echo "        INFRASTRUCTURE DESTROYED         "
    echo "=========================================="
    echo ""
    echo "[OK] Jenkins AMI backed up"
    echo "[OK] EKS cluster resources cleaned up"
    echo "[OK] Terraform infrastructure destroyed"
    echo "[OK] Kubectl configuration cleaned"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
}
