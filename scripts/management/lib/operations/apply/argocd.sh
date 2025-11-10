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

    log_message "Deploying ArgoCD applications..."
    
    # Ensure kubectl is configured for EKS cluster
    local eks_cluster_name
    eks_cluster_name=$(apply_tf_output eks_cluster_name)
    
    if ! kubectl config use-context "$eks_cluster_name" 2>/dev/null; then
        log_error "Failed to switch to EKS cluster context: $eks_cluster_name"
        handle_failure "$operation" 1 "eks_context_switch_argocd_apps"
    fi
    
    # Apply ArgoCD Application manifests
    log_message "Applying ArgoCD Application manifests from $GITOPS_DIR/applications/"
    
    if ! run_logged "$ARGOCD_LOG_FILE" kubectl apply -f "$GITOPS_DIR/applications/"; then
        log_error "Failed to deploy ArgoCD applications"
        handle_failure "$operation" 1 "argocd_applications_deploy"
    fi
    
    log_message "✓ ArgoCD applications deployed successfully"
    
    # Trigger initial sync on jenkins-platform application
    log_message "Triggering sync for jenkins-platform application..."
    if kubectl annotate application jenkins-platform -n argocd \
        argocd.argoproj.io/refresh=normal --overwrite 2>&1 | tee -a "$ARGOCD_LOG_FILE"; then
        log_message "✓ Refresh triggered - ArgoCD will reconcile jenkins-platform"
    else
        log_warning "Could not trigger refresh, relying on periodic reconciliation (3min cycle)"
    fi
    
    # Trigger initial sync on quiz-app application
    log_message "Triggering sync for quiz-app application..."
    if kubectl annotate application quiz-app -n argocd \
        argocd.argoproj.io/refresh=normal --overwrite 2>&1 | tee -a "$ARGOCD_LOG_FILE"; then
        log_message "✓ Refresh triggered - ArgoCD will reconcile quiz-app"
    else
        log_warning "Could not trigger refresh, relying on periodic reconciliation (3min cycle)"
    fi
    
    log_message ""
    log_message "ArgoCD is now syncing all applications:"
    log_message "  - aws-load-balancer-controller"
    log_message "  - external-secrets"
    log_message "  - jenkins-platform"
    log_message "  - quiz-app"
    log_message ""
    log_message "Monitor sync status: kubectl get applications -n argocd"
}

export -f apply_bootstrap_argocd apply_deploy_argocd_applications
