#!/bin/bash
# Streamlined destroy functions for Quiz App infrastructure

set -euo pipefail

# Ensure config is loaded
if [[ -z "${CONFIG_LOADER_SOURCED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../../helpers/config-loader.sh"
fi

# =============================================================================
# Cleanup EKS Cluster Resources
# =============================================================================
destroy_cleanup_eks_cluster() {
    log_info "Starting EKS cluster cleanup..."

    # Check if cluster exists
    if ! aws eks describe-cluster --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" &>/dev/null; then
        log_info "EKS cluster not found; skipping cleanup"
        return 0
    fi

    # Configure kubectl
    log_info "Configuring kubectl for cluster: $EKS_CLUSTER_NAME"
    if ! aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" &>/dev/null; then
        log_warning "Failed to configure kubectl; skipping Kubernetes cleanup"
        return 0
    fi

    # Verify cluster is reachable
    if ! kubectl cluster-info &>/dev/null; then
        log_warning "Cluster not reachable; skipping Kubernetes cleanup"
        return 0
    fi

    # Step 1: Clean up AWS resources that finalizers would normally handle
    # Since we're removing finalizers (Terraform owns these resources), we need to clean up manually
    
    # Deregister targets from Terraform-managed target groups
    log_info "Deregistering targets from Terraform-managed target groups..."
    for tg_arn in $(aws elbv2 describe-target-groups --region "$AWS_REGION" --query "TargetGroups[?contains(TargetGroupName, 'quiz')].TargetGroupArn" --output text 2>/dev/null); do
        local targets=$(aws elbv2 describe-target-health --region "$AWS_REGION" --target-group-arn "$tg_arn" --query 'TargetHealthDescriptions[*].Target.Id' --output text 2>/dev/null)
        if [[ -n "$targets" ]]; then
            log_info "Deregistering targets from $tg_arn"
            local target_specs=$(echo "$targets" | awk '{for(i=1;i<=NF;i++) printf "Id=%s ", $i}')
            aws elbv2 deregister-targets --region "$AWS_REGION" --target-group-arn "$tg_arn" --targets $target_specs 2>&1 | tee -a "$HELM_LOG_FILE" || true
        fi
    done
    
    # Clean up AWS Load Balancer Controller's security group rules
    log_info "Cleaning up Load Balancer Controller security group rules..."
    local cluster_sg=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
        --filters "Name=tag:kubernetes.io/cluster/$EKS_CLUSTER_NAME,Values=owned" \
        --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
    
    if [[ -n "$cluster_sg" && "$cluster_sg" != "None" ]]; then
        log_info "Found cluster security group: $cluster_sg"
        local alb_sgs=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=*alb-sg*" \
            --query 'SecurityGroups[*].GroupId' --output text 2>/dev/null)
        
        for alb_sg in $alb_sgs; do
            log_info "Checking for rules referencing ALB SG: $alb_sg"
            local rules=$(aws ec2 describe-security-groups --region "$AWS_REGION" --group-ids "$cluster_sg" \
                --query "SecurityGroups[0].IpPermissions[?contains(to_string(UserIdGroupPairs), '$alb_sg')]" \
                --output json 2>/dev/null)
            
            if [[ "$rules" != "[]" && -n "$rules" ]]; then
                log_info "Found rules to remove, revoking ingress..."
                echo "$rules" | jq -c '.[]' 2>/dev/null | while read -r rule; do
                    if [[ -n "$rule" ]]; then
                        log_info "Revoking rule: $rule"
                        aws ec2 revoke-security-group-ingress --region "$AWS_REGION" --group-id "$cluster_sg" \
                            --ip-permissions "$rule" 2>&1 | tee -a "$HELM_LOG_FILE" || {
                            log_warning "Failed to revoke rule, continuing..."
                        }
                    fi
                done
                log_info "Security group rules cleanup complete"
            else
                log_info "No rules found referencing $alb_sg"
            fi
        done
    else
        log_warning "Cluster security group not found, skipping SG cleanup"
    fi
    
    # Step 2: Delete ArgoCD applications FIRST to stop them from recreating resources
    log_info "Removing finalizers from ArgoCD applications..."
    kubectl get applications -n argocd -o json 2>/dev/null | \
        jq -r '.items[].metadata.name' | \
        while read -r app; do
            kubectl patch application "$app" -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 | tee -a "$HELM_LOG_FILE" || true
        done
    
    log_info "Deleting ArgoCD applications to stop resource reconciliation..."
    kubectl delete applications --all -n argocd --timeout=30s 2>&1 | tee -a "$HELM_LOG_FILE" || {
        log_warning "Failed to delete some ArgoCD applications"
    }
    
    # Wait a moment for ArgoCD to stop reconciling
    sleep 5
    
    # Step 3: Now remove finalizers from resources (ArgoCD won't recreate them anymore)
    log_info "Removing finalizers from TargetGroupBindings..."
    if kubectl get targetgroupbindings -A &>/dev/null; then
        kubectl get targetgroupbindings -A -o json 2>/dev/null | \
            jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null | \
            while read -r ns name; do
                if [[ -n "$ns" && -n "$name" ]]; then
                    log_info "Patching TGB: $ns/$name"
                    kubectl patch targetgroupbinding "$name" -n "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 | tee -a "$HELM_LOG_FILE" || true
                fi
            done
        
        # Force delete any remaining TGBs
        log_info "Force deleting all TargetGroupBindings..."
        kubectl delete targetgroupbindings --all -A --grace-period=0 --force --timeout=30s 2>&1 | tee -a "$HELM_LOG_FILE" || true
    else
        log_info "No TargetGroupBindings found or CRD not installed"
    fi
    
    log_info "Removing finalizers from ExternalSecrets..."
    kubectl get externalsecrets -A -o json 2>/dev/null | \
        jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
        while read -r ns name; do
            kubectl patch externalsecret "$name" -n "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 | tee -a "$HELM_LOG_FILE" || true
        done
    
    log_info "Removing finalizers from SecretStores and ClusterSecretStores..."
    kubectl get secretstores,clustersecretstores -A -o json 2>/dev/null | \
        jq -r '.items[] | "\(.kind) \(.metadata.namespace // "cluster") \(.metadata.name)"' | \
        while read -r kind ns name; do
            if [[ "$kind" == "ClusterSecretStore" ]]; then
                kubectl patch clustersecretstore "$name" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 | tee -a "$HELM_LOG_FILE" || true
            else
                kubectl patch secretstore "$name" -n "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 | tee -a "$HELM_LOG_FILE" || true
            fi
        done
    
    # Step 4: Uninstall ArgoCD (applications already deleted, finalizers removed)
    log_info "Uninstalling ArgoCD..."
    helm uninstall argocd -n argocd --timeout=5m 2>&1 | tee -a "$HELM_LOG_FILE" || {
        log_warning "Failed to uninstall ArgoCD"
    }

    log_info "EKS cluster cleanup complete"
}

# =============================================================================
# Run Terraform Destroy
# =============================================================================
destroy_run_terraform() {
    local previous_dir="$PWD"

    echo ""
    echo "================================"
    echo "  🗑️  Terraform Destruction"
    echo "================================"
    echo ""

    log_info "Starting Terraform destroy..."
    
    cd "$TERRAFORM_DIR" || {
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    }

    echo "Running terraform destroy..."
    echo ""
    echo "✓ Starting infrastructure destruction."
    echo ""
    echo "🖥️  To continue monitoring: monitor-deployment -h"
    echo "⚠️  Don't close this terminal"
    echo ""

    # Run terraform destroy (logs only to file, not terminal)
    run_logged "$TERRAFORM_LOG_FILE" terraform destroy -auto-approve || {
        log_error "Terraform destroy failed"
        echo ""
        echo "❌ Terraform destroy failed. Check logs: $TERRAFORM_LOG_FILE"
        cd "$previous_dir"
        return 1
    }

    echo ""
    echo "✓ Terraform destroy completed successfully."
    log_info "Terraform destroy completed"
    
    cd "$previous_dir"
}

# =============================================================================
# Cleanup Kubectl Config
# =============================================================================
destroy_cleanup_kubeconfig() {
    log_info "Cleaning up kubectl configuration..."
    
    kubectl config delete-context "$EKS_CLUSTER_NAME" 2>/dev/null || true
    kubectl config delete-cluster "$EKS_CLUSTER_NAME" 2>/dev/null || true
    
    log_info "Kubectl configuration cleanup complete"
}

# =============================================================================
# Summary
# =============================================================================
destroy_log_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║               INFRASTRUCTURE DESTROYED                         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✓ EKS cluster resources cleaned up"
    echo "✓ Terraform infrastructure destroyed"
    echo "✓ Kubectl configuration cleaned"
    echo ""
    echo "Logs available: $LOG_DIR"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================
destroy_execute() {
    print_log_locations || true
    
    echo "Starting infrastructure destruction..."
    echo ""
    
    # Step 1: Clean up Kubernetes resources
    destroy_cleanup_eks_cluster || {
        log_warning "EKS cleanup had issues, continuing with Terraform destroy..."
    }
    
    # Step 2: Destroy infrastructure with Terraform
    destroy_run_terraform || {
        log_error "Terraform destroy failed"
        return 1
    }
    
    # Step 3: Clean up local kubectl config
    destroy_cleanup_kubeconfig || true
    
    # Summary
    destroy_log_summary
    
    echo "Destruction complete!"
}
