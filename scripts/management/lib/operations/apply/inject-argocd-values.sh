#!/bin/bash
# =============================================================================
# Inject Terraform Outputs into ArgoCD Manifests
# =============================================================================
# This script updates ArgoCD application manifests with values from Terraform
# outputs (IRSA role ARNs, ACM certificate ARN, etc.)
#
# Run this after: terraform apply
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is at: quiz-app/iac/scripts/management/lib/operations/apply
# Go up 5 levels to reach quiz-app/iac/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
TERRAFORM_ROOT="$PROJECT_ROOT/terraform"
# GitOps is at quiz-app/gitops (one level up from iac, then into gitops)
GITOPS_ROOT="$(cd "$PROJECT_ROOT/../gitops" && pwd)"

# Source helpers
source "$SCRIPT_DIR/../../helpers/logging-helpers.sh" 2>/dev/null || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Could not load logging helpers"
    exit 1
}

inject_terraform_values() {
    log_info "Injecting Terraform outputs into GitOps manifests..."
    
    # Change to Terraform directory
    cd "$TERRAFORM_ROOT"
    
    # Check if Terraform state exists
    if [[ ! -f "terraform.tfstate" ]]; then
        log_error "Terraform state not found. Run 'terraform apply' first."
        return 1
    fi
    
    # Get Terraform outputs
    log_info "Fetching Terraform outputs..."
    ALB_ROLE=$(terraform output -raw alb_controller_role_arn 2>/dev/null || echo "")
    ESO_ROLE=$(terraform output -raw external_secrets_role_arn 2>/dev/null || echo "")
    CERT_ARN=$(terraform output -raw acm_certificate_arn 2>/dev/null || echo "")
    TG_ARN=$(terraform output -raw quiz_app_target_group_arn 2>/dev/null || echo "")
    ARGOCD_TG_ARN=$(terraform output -raw argocd_target_group_arn 2>/dev/null || echo "")
    ALB_SG_ID=$(terraform output -raw alb_security_group_id 2>/dev/null || echo "")
    
    # Validate outputs
    if [[ -z "$ALB_ROLE" ]] || [[ -z "$ESO_ROLE" ]]; then
        log_error "Required Terraform outputs not found"
        log_error "  ALB Controller Role: $ALB_ROLE"
        log_error "  External Secrets Role: $ESO_ROLE"
        return 1
    fi
    
    log_info "Terraform outputs:"
    log_info "  ALB Controller Role ARN: $ALB_ROLE"
    log_info "  External Secrets Role ARN: $ESO_ROLE"
    log_info "  ACM Certificate ARN: $CERT_ARN"
    log_info "  Quiz App Target Group ARN: $TG_ARN"
    log_info "  ArgoCD Target Group ARN: $ARGOCD_TG_ARN"
    log_info "  ALB Security Group ID: $ALB_SG_ID"
    
    # Change to GitOps directory
    cd "$GITOPS_ROOT"
    
    # Update ALB Controller IRSA (replace the value line after role-arn)
    log_info "Updating AWS Load Balancer Controller IRSA..."
    sed -i "s|value: \".*\" # Injected by Terraform|value: \"$ALB_ROLE\" # Injected by Terraform|g" \
      applications/aws-load-balancer-controller.yaml
    
    # Update External Secrets IRSA (replace the value line after role-arn)
    log_info "Updating External Secrets Operator IRSA..."
    sed -i "s|value: \".*\" # Injected by Terraform|value: \"$ESO_ROLE\" # Injected by Terraform|g" \
      applications/external-secrets.yaml
    
    # Update quiz-app values (replace any existing value)
    if [[ -n "$TG_ARN" ]]; then
        log_info "Updating Quiz App TargetGroupBinding ARN..."
        sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$TG_ARN\" # Injected by Terraform|g" \
          quiz-app/values.yaml
    fi
    
    # Update ArgoCD TargetGroupBinding (replace any existing value)
    if [[ -n "$ARGOCD_TG_ARN" ]]; then
        log_info "Updating ArgoCD TargetGroupBinding ARN..."
        sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$ARGOCD_TG_ARN\" # Injected by Terraform|g" \
          argocd/argocd-targetgroupbinding.yaml
    fi
    
    # Update security group IDs in both files (replace any existing value)
    if [[ -n "$ALB_SG_ID" ]]; then
        log_info "Updating ALB Security Group IDs..."
        sed -i "s|groupID: \".*\" # Injected by Terraform|groupID: \"$ALB_SG_ID\" # Injected by Terraform|g" \
          quiz-app/values.yaml \
          argocd/argocd-targetgroupbinding.yaml
    fi
    
    log_success "✓ Terraform values injected into GitOps files"
    
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inject_terraform_values
    exit $?
fi
