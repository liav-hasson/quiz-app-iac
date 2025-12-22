#!/bin/bash
# tasks/terraform.sh
# Terraform operations: init, apply, destroy

# Guard against double-loading
[[ -n "${_TASK_TERRAFORM_LOADED:-}" ]] && return 0
_TASK_TERRAFORM_LOADED=1

# =============================================================================
# Terraform Apply
# =============================================================================

task_terraform_apply() {
    local previous_dir="$PWD"
    
    log_info "Initializing Terraform workspace"
    
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    
    cd "$TERRAFORM_DIR" || return 1
    
    # Terraform init
    log_info "Running terraform init..."
    if ! run_logged "terraform init" terraform init; then
        log_error "terraform init failed"
        cd "$previous_dir"
        return 1
    fi
    log_success "Terraform init completed"
    
    # Terraform apply
    log_info "Running terraform apply (this may take 15-20 minutes)..."
    echo ""
    echo -e "${YELLOW}[INFO]${NC} Monitor progress: monitor-deployment --follow"
    echo -e "${YELLOW}[INFO]${NC} Do not close this terminal"
    echo ""
    
    if ! run_logged "terraform apply" terraform apply -auto-approve; then
        log_error "terraform apply failed"
        cd "$previous_dir"
        return 1
    fi
    
    log_success "Terraform apply completed"
    cd "$previous_dir"
    return 0
}

# =============================================================================
# Terraform Destroy
# =============================================================================

task_terraform_destroy() {
    local previous_dir="$PWD"
    
    log_info "Starting Terraform destroy"
    
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    
    cd "$TERRAFORM_DIR" || return 1
    
    echo ""
    echo -e "${YELLOW}[INFO]${NC} Monitor progress: monitor-deployment --follow"
    echo -e "${YELLOW}[INFO]${NC} Do not close this terminal"
    echo ""
    
    if ! run_logged "terraform destroy" terraform destroy -auto-approve; then
        log_error "terraform destroy failed"
        cd "$previous_dir"
        return 1
    fi
    
    log_success "Terraform destroy completed"
    cd "$previous_dir"
    return 0
}

# =============================================================================
# EKS Configuration
# =============================================================================

task_configure_eks() {
    log_info "Configuring kubectl access to EKS cluster"
    
    if ! run_logged "aws eks update-kubeconfig" \
        aws eks update-kubeconfig \
            --name "$EKS_CLUSTER_NAME" \
            --region "$AWS_REGION" \
            --alias "$EKS_CLUSTER_NAME"; then
        log_error "Failed to update kubeconfig for $EKS_CLUSTER_NAME"
        return 1
    fi
    
    # Switch context
    if ! kubectl config use-context "$EKS_CLUSTER_NAME" &>/dev/null; then
        log_error "Failed to switch kubectl context to $EKS_CLUSTER_NAME"
        return 1
    fi
    
    log_success "Kubectl configured for $EKS_CLUSTER_NAME"
    return 0
}

# =============================================================================
# Kubeconfig Cleanup
# =============================================================================

task_cleanup_kubeconfig() {
    log_info "Cleaning up kubectl configuration"
    
    kubectl config delete-context "$EKS_CLUSTER_NAME" 2>/dev/null || true
    kubectl config delete-cluster "$EKS_CLUSTER_NAME" 2>/dev/null || true
    
    log_success "Kubectl configuration cleaned"
    return 0
}

# =============================================================================
# Terraform Output Helper
# =============================================================================

tf_output() {
    local key="$1"
    
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    
    local output
    output=$(cd "$TERRAFORM_DIR" && terraform output -raw "$key" 2>/dev/null) || {
        log_debug "Terraform output '$key' not found"
        echo ""
        return 0
    }
    
    echo "$output"
}
