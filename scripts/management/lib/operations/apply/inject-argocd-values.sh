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
# Resolve paths relative to the script without touching global PROJECT_ROOT from config-loader
APPLY_LIB_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IAC_ROOT="$(cd "$APPLY_LIB_ROOT/../.." && pwd)"
TERRAFORM_ROOT="$IAC_ROOT/terraform"
GITOPS_ROOT="$(cd "$IAC_ROOT/../gitops" && pwd)"

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
    EBS_CSI_ROLE=$(terraform output -raw ebs_csi_driver_role_arn 2>/dev/null || echo "")
    CERT_ARN=$(terraform output -raw acm_certificate_arn 2>/dev/null || echo "")
    BACKEND_TG_ARN=$(terraform output -raw quiz_backend_target_group_arn 2>/dev/null || echo "")
    FRONTEND_TG_ARN=$(terraform output -raw quiz_frontend_target_group_arn 2>/dev/null || echo "")
    BACKEND_DEV_TG_ARN=$(terraform output -raw quiz_backend_dev_target_group_arn 2>/dev/null || echo "")
    FRONTEND_DEV_TG_ARN=$(terraform output -raw quiz_frontend_dev_target_group_arn 2>/dev/null || echo "")
    ARGOCD_TG_ARN=$(terraform output -raw argocd_target_group_arn 2>/dev/null || echo "")
    GRAFANA_TG_ARN=$(terraform output -raw grafana_target_group_arn 2>/dev/null || echo "")
    LOKI_TG_ARN=$(terraform output -raw loki_target_group_arn 2>/dev/null || echo "")
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
    log_info "  EBS CSI Driver Role ARN: $EBS_CSI_ROLE"
    log_info "  ACM Certificate ARN: $CERT_ARN"
    log_info "  Quiz Backend Target Group ARN: $BACKEND_TG_ARN"
    log_info "  Quiz Frontend Target Group ARN: $FRONTEND_TG_ARN"
    log_info "  Quiz Backend DEV Target Group ARN: $BACKEND_DEV_TG_ARN"
    log_info "  Quiz Frontend DEV Target Group ARN: $FRONTEND_DEV_TG_ARN"
    log_info "  ArgoCD Target Group ARN: $ARGOCD_TG_ARN"
    log_info "  Grafana Target Group ARN: $GRAFANA_TG_ARN"
    log_info "  Loki Target Group ARN: $LOKI_TG_ARN"
    log_info "  ALB Security Group ID: $ALB_SG_ID"
    
    # Change to GitOps directory
    cd "$GITOPS_ROOT"
    
    # Update ALB Controller IRSA (replace the value line after role-arn)
    log_info "Updating AWS Load Balancer Controller IRSA..."
    sed -i "s|value: \".*\" # Injected by Terraform|value: \"$ALB_ROLE\" # Injected by Terraform|g" \
      apps/platform/aws-load-balancer-controller.yaml
    
    # Update External Secrets IRSA (replace the value line after role-arn)
    log_info "Updating External Secrets Operator IRSA..."
    sed -i "s|value: \".*\" # Injected by Terraform|value: \"$ESO_ROLE\" # Injected by Terraform|g" \
      apps/platform/external-secrets.yaml
    
    # Update quiz-backend values (replace any existing value)
  if [[ -n "$BACKEND_TG_ARN" ]]; then
        log_info "Updating Quiz Backend TargetGroupBinding ARN..."
    sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$BACKEND_TG_ARN\" # Injected by Terraform|g" \
          charts/workloads/quiz-backend/values.yaml
    fi

  if [[ -n "$FRONTEND_TG_ARN" ]]; then
    log_info "Updating Quiz Frontend TargetGroupBinding ARN..."
    sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$FRONTEND_TG_ARN\" # Injected by Terraform|g" \
      charts/workloads/quiz-frontend/values.yaml
  fi

    # Update quiz-backend DEV values
    if [[ -n "$BACKEND_DEV_TG_ARN" ]]; then
        log_info "Updating Quiz Backend DEV TargetGroupBinding ARN..."
        sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$BACKEND_DEV_TG_ARN\" # Injected by Terraform|g" \
          charts/workloads/quiz-backend/values-dev.yaml
    fi

    # Update quiz-frontend DEV values
    if [[ -n "$FRONTEND_DEV_TG_ARN" ]]; then
        log_info "Updating Quiz Frontend DEV TargetGroupBinding ARN..."
        sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$FRONTEND_DEV_TG_ARN\" # Injected by Terraform|g" \
          charts/workloads/quiz-frontend/values-dev.yaml
    fi
    
    # Update ArgoCD TargetGroupBinding (replace any existing value)
    if [[ -n "$ARGOCD_TG_ARN" ]]; then
        log_info "Updating ArgoCD TargetGroupBinding ARN..."
        sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$ARGOCD_TG_ARN\" # Injected by Terraform|g" \
          charts/platform/prerequisites/argocd-targetgroupbinding.yaml
    fi
    
    # Update Grafana TargetGroupBinding (replace any existing value)
    if [[ -n "$GRAFANA_TG_ARN" ]]; then
        log_info "Updating Grafana TargetGroupBinding ARN..."
        sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$GRAFANA_TG_ARN\" # Injected by Terraform|g" \
          charts/platform/prerequisites/grafana-targetgroupbinding.yaml
    fi
    
    # Update Loki TargetGroupBinding (replace any existing value)
    if [[ -n "$LOKI_TG_ARN" ]]; then
        log_info "Updating Loki TargetGroupBinding ARN..."
        sed -i "s|targetGroupARN: \".*\" # Injected by Terraform|targetGroupARN: \"$LOKI_TG_ARN\" # Injected by Terraform|g" \
          charts/platform/prerequisites/loki-targetgroupbinding.yaml
    fi
    
    # Update security group IDs (replace any existing value)
    if [[ -n "$ALB_SG_ID" ]]; then
        log_info "Updating ALB Security Group IDs..."
        sed -i "s|groupID: \".*\" # Injected by Terraform|groupID: \"$ALB_SG_ID\" # Injected by Terraform|g" \
          charts/workloads/quiz-backend/values.yaml \
          charts/workloads/quiz-frontend/values.yaml \
          charts/workloads/quiz-backend/values-dev.yaml \
          charts/workloads/quiz-frontend/values-dev.yaml \
          charts/platform/prerequisites/argocd-targetgroupbinding.yaml \
          charts/platform/prerequisites/grafana-targetgroupbinding.yaml \
          charts/platform/prerequisites/loki-targetgroupbinding.yaml
    fi
    
    # Note: EBS CSI Driver role is managed directly in Terraform addon resource
    log_info "EBS CSI Driver role configured in Terraform (not injected into GitOps)"
    
    log_success "✓ Terraform values injected into GitOps files"
    
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inject_terraform_values
    exit $?
fi
