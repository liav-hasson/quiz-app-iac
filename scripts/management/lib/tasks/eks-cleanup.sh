#!/bin/bash
# tasks/eks-cleanup.sh
# EKS cluster resource cleanup for destroy operations
# Handles finalizers, ArgoCD applications, NLB cleanup, etc.

# Guard against double-loading
[[ -n "${_TASK_EKS_CLEANUP_LOADED:-}" ]] && return 0
_TASK_EKS_CLEANUP_LOADED=1

# =============================================================================
# Main Cleanup Function
# =============================================================================

task_cleanup_eks_cluster() {
    log_info "Starting EKS cluster cleanup"
    
    # Check if cluster exists
    if ! aws eks describe-cluster --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" &>/dev/null; then
        log_info "EKS cluster not found, skipping cleanup"
        return 0
    fi
    
    # Configure kubectl
    log_info "Configuring kubectl for cluster: $EKS_CLUSTER_NAME"
    if ! aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" &>/dev/null; then
        log_warning "Failed to configure kubectl, skipping Kubernetes cleanup"
        return 0
    fi
    
    # Verify cluster is reachable
    if ! kubectl cluster-info &>/dev/null; then
        log_warning "Cluster not reachable, skipping Kubernetes cleanup"
        return 0
    fi
    
    # Step 1: Remove ArgoCD application finalizers and delete apps
    _cleanup_argocd_applications
    
    # Step 2: Remove External Secrets finalizers
    _cleanup_external_secrets
    
    # Step 3: Uninstall ArgoCD Helm release
    _cleanup_argocd_helm
    
    # Step 4: Clean up Istio Gateway NLB
    _cleanup_istio_nlb
    
    # Step 5: Remove Istio CRD finalizers
    _cleanup_istio_resources
    
    # Step 6: Delete application namespaces
    _cleanup_namespaces
    
    # Step 7: Wait for PVs to be deleted
    _cleanup_persistent_volumes
    
    log_success "EKS cluster cleanup complete"
    return 0
}

# =============================================================================
# ArgoCD Applications Cleanup
# =============================================================================

_cleanup_argocd_applications() {
    log_info "Removing finalizers from ArgoCD applications..."
    
    # Remove finalizers
    kubectl get applications -n argocd -o json 2>/dev/null | \
        jq -r '.items[].metadata.name' 2>/dev/null | \
        while read -r app; do
            [[ -z "$app" ]] && continue
            kubectl patch application "$app" -n argocd \
                -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        done
    
    # Delete applications
    log_info "Deleting ArgoCD applications..."
    kubectl delete applications --all -n argocd --timeout=30s 2>/dev/null || {
        log_warning "Failed to delete some ArgoCD applications"
    }
    
    # Brief wait for ArgoCD to stop reconciling
    sleep 5
}

# =============================================================================
# External Secrets Cleanup
# =============================================================================

_cleanup_external_secrets() {
    log_info "Removing finalizers from External Secrets resources..."
    
    # ExternalSecrets
    kubectl get externalsecrets -A -o json 2>/dev/null | \
        jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null | \
        while read -r ns name; do
            [[ -z "$ns" || -z "$name" ]] && continue
            kubectl patch externalsecret "$name" -n "$ns" \
                -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        done
    
    # SecretStores and ClusterSecretStores
    kubectl get secretstores,clustersecretstores -A -o json 2>/dev/null | \
        jq -r '.items[] | "\(.kind) \(.metadata.namespace // "cluster") \(.metadata.name)"' 2>/dev/null | \
        while read -r kind ns name; do
            [[ -z "$kind" || -z "$name" ]] && continue
            if [[ "$kind" == "ClusterSecretStore" ]]; then
                kubectl patch clustersecretstore "$name" \
                    -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            else
                kubectl patch secretstore "$name" -n "$ns" \
                    -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            fi
        done
}

# =============================================================================
# ArgoCD Helm Cleanup
# =============================================================================

_cleanup_argocd_helm() {
    log_info "Uninstalling ArgoCD Helm release..."
    helm uninstall argocd -n argocd --timeout=5m 2>/dev/null || {
        log_warning "Failed to uninstall ArgoCD (may already be removed)"
    }
}

# =============================================================================
# Istio NLB Cleanup
# =============================================================================

_cleanup_istio_nlb() {
    log_info "Cleaning up Istio Gateway LoadBalancer service..."
    
    if ! kubectl get namespace istio-ingress &>/dev/null; then
        return 0
    fi
    
    # Delete the gateway service to trigger NLB deletion
    kubectl delete service -n istio-ingress --all --timeout=60s 2>/dev/null || true
    
    # Wait for NLB to be deleted
    log_info "Waiting for Istio NLB deletion..."
    local nlb_wait=0
    local nlb_max_wait=120
    
    while [[ $nlb_wait -lt $nlb_max_wait ]]; do
        local nlb_count
        nlb_count=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
            --query "LoadBalancers[?contains(LoadBalancerName, 'istio') || contains(LoadBalancerName, 'quiz-app-istio')].LoadBalancerArn" \
            --output text 2>/dev/null | wc -w)
        
        if [[ $nlb_count -eq 0 ]]; then
            log_info "Istio NLB deleted"
            return 0
        fi
        
        log_info "Waiting for NLB deletion... ($nlb_wait/$nlb_max_wait seconds)"
        sleep 10
        nlb_wait=$((nlb_wait + 10))
    done
    
    # Force delete if timeout
    log_warning "NLB deletion timed out, forcing cleanup..."
    for nlb_arn in $(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName, 'istio') || contains(LoadBalancerName, 'quiz-app-istio')].LoadBalancerArn" \
        --output text 2>/dev/null); do
        log_info "Force deleting NLB: $nlb_arn"
        aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$nlb_arn" 2>/dev/null || true
    done
}

# =============================================================================
# Istio Resources Cleanup
# =============================================================================

_cleanup_istio_resources() {
    log_info "Removing finalizers from Istio resources..."
    
    local istio_crds=(
        "virtualservices"
        "gateways"
        "destinationrules"
        "serviceentries"
        "envoyfilters"
        "sidecars"
        "authorizationpolicies"
        "peerauthentications"
        "requestauthentications"
        "telemetries"
    )
    
    for crd in "${istio_crds[@]}"; do
        # Check if CRD exists (in any API group)
        if kubectl get crd "${crd}.networking.istio.io" &>/dev/null 2>&1 || \
           kubectl get crd "${crd}.security.istio.io" &>/dev/null 2>&1 || \
           kubectl get crd "${crd}.telemetry.istio.io" &>/dev/null 2>&1; then
            
            kubectl get "$crd" -A -o json 2>/dev/null | \
                jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null | \
                while read -r ns name; do
                    [[ -z "$ns" || -z "$name" ]] && continue
                    kubectl patch "$crd" "$name" -n "$ns" \
                        -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
                done
        fi
    done
}

# =============================================================================
# Namespace Cleanup
# =============================================================================

_cleanup_namespaces() {
    log_info "Deleting application namespaces..."
    
    local namespaces=(
        "monitoring"
        "mongodb"
        "quiz-backend"
        "quiz-frontend"
        "jenkins"
        "istio-system"
        "istio-ingress"
    )
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null; then
            log_info "Deleting namespace: $ns"
            kubectl delete namespace "$ns" --timeout=2m 2>/dev/null || {
                log_warning "Timeout deleting $ns, forcing..."
                kubectl delete namespace "$ns" --grace-period=0 --force 2>/dev/null || true
            }
        fi
    done
}

# =============================================================================
# Persistent Volumes Cleanup
# =============================================================================

_cleanup_persistent_volumes() {
    log_info "Waiting for PVs with Delete policy to be cleaned up..."
    
    local max_wait=60
    local waited=0
    
    while [[ $waited -lt $max_wait ]]; do
        local remaining
        remaining=$(kubectl get pv -o json 2>/dev/null | \
            jq -r '.items[] | select(.spec.persistentVolumeReclaimPolicy=="Delete") | .metadata.name' | wc -l)
        
        if [[ $remaining -eq 0 ]]; then
            log_info "All dynamic PVs deleted"
            return 0
        fi
        
        log_info "Waiting for $remaining PV(s) to be deleted... ($waited/$max_wait seconds)"
        sleep 5
        waited=$((waited + 5))
    done
    
    log_warning "Some PVs may still exist"
}
