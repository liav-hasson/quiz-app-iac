#!/bin/bash
# tasks/inject-values.sh
# Inject Terraform outputs into GitOps manifests (IRSA roles, ACM certs, etc.)

# Guard against double-loading
[[ -n "${_TASK_INJECT_VALUES_LOADED:-}" ]] && return 0
_TASK_INJECT_VALUES_LOADED=1

# =============================================================================
# Inject Terraform Values
# =============================================================================

task_inject_terraform_values() {
    log_info "Injecting Terraform outputs into GitOps manifests"
    
    # Change to Terraform directory
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    
    cd "$TERRAFORM_DIR" || return 1
    
    # Check if Terraform state exists
    if [[ ! -f "terraform.tfstate" ]]; then
        log_error "Terraform state not found. Run 'terraform apply' first."
        return 1
    fi
    
    # Get Terraform outputs
    log_info "Fetching Terraform outputs..."
    local alb_role eso_role ebs_csi_role cert_arn
    
    alb_role=$(terraform output -raw alb_controller_role_arn 2>/dev/null || echo "")
    eso_role=$(terraform output -raw external_secrets_role_arn 2>/dev/null || echo "")
    ebs_csi_role=$(terraform output -raw ebs_csi_driver_role_arn 2>/dev/null || echo "")
    cert_arn=$(terraform output -raw acm_certificate_arn 2>/dev/null || echo "")
    
    # Validate required outputs
    if [[ -z "$alb_role" ]] || [[ -z "$eso_role" ]]; then
        log_error "Required Terraform outputs not found"
        log_error "  ALB Controller Role: ${alb_role:-<empty>}"
        log_error "  External Secrets Role: ${eso_role:-<empty>}"
        return 1
    fi
    
    log_info "Terraform outputs:"
    log_info "  ALB Controller Role ARN: $alb_role"
    log_info "  External Secrets Role ARN: $eso_role"
    log_info "  EBS CSI Driver Role ARN: ${ebs_csi_role:-<managed by Terraform>}"
    log_info "  ACM Certificate ARN: ${cert_arn:-<not set>}"
    
    # Change to GitOps directory
    if [[ ! -d "$GITOPS_DIR" ]]; then
        log_error "GitOps directory not found: $GITOPS_DIR"
        return 1
    fi
    
    cd "$GITOPS_DIR" || return 1
    
    # Update ALB Controller IRSA
    log_info "Updating AWS Load Balancer Controller IRSA..."
    if [[ -f "apps/platform/aws-load-balancer-controller.yaml" ]]; then
        sed -i "s|value: \".*\" # Injected by Terraform|value: \"$alb_role\" # Injected by Terraform|g" \
            apps/platform/aws-load-balancer-controller.yaml
    else
        log_warning "ALB Controller manifest not found"
    fi
    
    # Update External Secrets IRSA
    log_info "Updating External Secrets Operator IRSA..."
    if [[ -f "apps/platform/external-secrets.yaml" ]]; then
        sed -i "s|value: \".*\" # Injected by Terraform|value: \"$eso_role\" # Injected by Terraform|g" \
            apps/platform/external-secrets.yaml
    else
        log_warning "External Secrets manifest not found"
    fi
    
    # Update Istio Gateway with ACM certificate ARN
    if [[ -n "$cert_arn" ]]; then
        log_info "Updating Istio Gateway ACM Certificate ARN..."
        if [[ -f "apps/istio/gateway.yaml" ]]; then
            sed -i "s|service.beta.kubernetes.io/aws-load-balancer-ssl-cert: \".*\" # Injected by Terraform|service.beta.kubernetes.io/aws-load-balancer-ssl-cert: \"$cert_arn\" # Injected by Terraform|g" \
                apps/istio/gateway.yaml
        else
            log_warning "Istio Gateway manifest not found"
        fi
    fi
    
    log_success "Terraform values injected into GitOps files"
    return 0
}
