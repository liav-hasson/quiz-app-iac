#!/bin/bash

set -euo pipefail

# =============================================================================
# ArgoCD Bootstrap and Deployment Functions
# =============================================================================
# Adapted from weather app infrastructure for quiz app single-cluster architecture
# =============================================================================

apply_bootstrap_argocd() {
    local operation="$1"

    log_message "Deploying ArgoCD to EKS cluster..."
    
    # Ensure kubectl is configured for EKS cluster
    local eks_cluster_name
    eks_cluster_name=$(apply_tf_output eks_cluster_name)
    
    if ! kubectl config use-context "$eks_cluster_name" 2>/dev/null; then
        log_error "Failed to switch to EKS cluster context: $eks_cluster_name"
        handle_failure "$operation" 1 "eks_context_switch_argocd"
    fi
    
    log_message "Kubectl context switched to $eks_cluster_name"
    
    # Add Argo CD Helm repository
    log_message "Adding Argo CD Helm repository..."
    helm repo add argo https://argoproj.github.io/argo-helm 2>&1 | tee -a "$HELM_LOG_FILE" || true
    helm repo update 2>&1 | tee -a "$HELM_LOG_FILE"
    
    # Check if ArgoCD is already installed
    if helm list -n argocd 2>/dev/null | grep -q argocd; then
        log_message "ArgoCD already installed, upgrading..."
        
        if ! run_logged "$HELM_LOG_FILE" helm upgrade argocd argo/argo-cd \
            --namespace argocd \
            --set server.extraArgs[0]="--insecure" \
            --wait --timeout 10m; then
            log_error "ArgoCD upgrade failed"
            handle_failure "$operation" 1 "argocd_upgrade"
        fi
    else
        log_message "Installing ArgoCD..."
        
        if ! run_logged "$HELM_LOG_FILE" helm install argocd argo/argo-cd \
            --namespace argocd \
            --create-namespace \
            --set server.extraArgs[0]="--insecure" \
            --wait --timeout 10m; then
            log_error "ArgoCD installation failed"
            handle_failure "$operation" 1 "argocd_install"
        fi
    fi
    
    log_message "✓ ArgoCD deployed successfully"
}

apply_deploy_argocd_applications() {
    local operation="$1"

    log_message "Deploying ArgoCD root application..."

    # Ensure kubectl is configured for EKS cluster
    local eks_cluster_name
    eks_cluster_name=$(apply_tf_output eks_cluster_name)
    
    if ! kubectl config use-context "$eks_cluster_name" 2>/dev/null; then
        log_error "Failed to switch to EKS cluster context: $eks_cluster_name"
        handle_failure "$operation" 1 "eks_context_switch_argocd_apps"
    fi

    # Deploy the root ArgoCD application
    local root_app_manifest="$GITOPS_DIR/bootstrap/root-app.yaml"
    if [[ ! -f "$root_app_manifest" ]]; then
        log_error "root.yml not found at: $root_app_manifest"
        handle_failure "$operation" 1 "argocd_root_manifest_missing"
    fi

    log_message "Applying root application manifest: $root_app_manifest"
    if ! run_logged "$ARGOCD_LOG_FILE" kubectl apply -f "$root_app_manifest"; then
        log_error "Failed to deploy root ArgoCD application"
        handle_failure "$operation" 1 "argocd_root_deploy"
    fi

    log_message "Root application deployed successfully"
    log_message "ArgoCD will now automatically discover and sync all applications from Git."
    log_message ""
    log_message "Monitor sync status using: kubectl get applications -n argocd"
    log_message ""
}

export -f apply_bootstrap_argocd apply_deploy_argocd_applications
