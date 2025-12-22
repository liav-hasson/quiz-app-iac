#!/bin/bash
# tasks/argocd.sh
# ArgoCD bootstrap and application deployment

# Guard against double-loading
[[ -n "${_TASK_ARGOCD_LOADED:-}" ]] && return 0
_TASK_ARGOCD_LOADED=1

# =============================================================================
# Bootstrap ArgoCD
# =============================================================================

task_bootstrap_argocd() {
    log_info "Deploying ArgoCD to EKS cluster"
    
    # Verify kubectl context
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cluster not reachable. Run task_configure_eks first."
        return 1
    fi
    
    # Add Argo CD Helm repository
    log_info "Adding ArgoCD Helm repository..."
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update argo 2>/dev/null || helm repo update 2>/dev/null
    
    # Check if ArgoCD is already installed
    if helm list -n argocd 2>/dev/null | grep -q argocd; then
        log_info "ArgoCD already installed, upgrading..."
        
        if ! run_logged "helm upgrade argocd" \
            helm upgrade argocd argo/argo-cd \
                --namespace argocd \
                --set server.extraArgs[0]="--insecure" \
                --wait --timeout 10m; then
            log_error "ArgoCD upgrade failed"
            return 1
        fi
    else
        log_info "Installing ArgoCD..."
        
        if ! run_logged "helm install argocd" \
            helm install argocd argo/argo-cd \
                --namespace argocd \
                --create-namespace \
                --set server.extraArgs[0]="--insecure" \
                --wait --timeout 10m; then
            log_error "ArgoCD installation failed"
            return 1
        fi
    fi
    
    log_success "ArgoCD deployed successfully"
    return 0
}

# =============================================================================
# Deploy ArgoCD Applications
# =============================================================================

task_deploy_argocd_apps() {
    log_info "Deploying ArgoCD root application"
    
    # Verify kubectl context
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cluster not reachable"
        return 1
    fi
    
    # Deploy the root ArgoCD application
    local root_app_manifest="$GITOPS_DIR/bootstrap/root-app.yaml"
    
    if [[ ! -f "$root_app_manifest" ]]; then
        log_error "Root application manifest not found: $root_app_manifest"
        return 1
    fi
    
    log_info "Applying root application manifest..."
    if ! run_logged "kubectl apply root-app" kubectl apply -f "$root_app_manifest"; then
        log_error "Failed to deploy root ArgoCD application"
        return 1
    fi
    
    log_success "Root application deployed"
    log_info "ArgoCD will automatically sync all applications from Git"
    log_info "Monitor sync: kubectl get applications -n argocd"
    
    return 0
}

# =============================================================================
# Uninstall ArgoCD
# =============================================================================

task_uninstall_argocd() {
    log_info "Uninstalling ArgoCD..."
    
    if ! helm list -n argocd 2>/dev/null | grep -q argocd; then
        log_info "ArgoCD not installed, skipping"
        return 0
    fi
    
    if ! helm uninstall argocd -n argocd --timeout 5m 2>/dev/null; then
        log_warning "Failed to uninstall ArgoCD via Helm"
    fi
    
    log_success "ArgoCD uninstalled"
    return 0
}
