#!/bin/bash
# kube-helpers.sh
# Safe Kubernetes and Helm operations for cluster cleanup
# These functions make destroy operations idempotent and resilient

# This script assumes logging-helpers.sh has been sourced for log functions

# Check if EKS cluster exists
safe_describe_eks() {
    local cluster="$1"
    local region="${2:-$AWS_REGION}"
    
    if aws eks describe-cluster --name "$cluster" --region "$region" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if kubectl can reach the cluster
cluster_reachable() {
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if kubectl version --short >/dev/null 2>&1; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_info "Cluster unreachable (attempt $attempt/$max_attempts), retrying in 5s..."
            sleep 5
        fi
        
        ((attempt++))
    done
    
    return 1
}

# Check if Helm release exists
helm_release_exists() {
    local release="$1"
    local namespace="$2"
    
    if helm list -n "$namespace" -q 2>/dev/null | grep -xq "$release"; then
        return 0
    else
        return 1
    fi
}

# Safely uninstall Helm release with proper error handling
# Uses --wait to ensure finalizers complete (e.g., ArgoCD cleaning up Applications)
safe_helm_uninstall() {
    local release="$1"
    local namespace="$2"
    local log_file="$3"
    local timeout="${4:-10m}"  # Default 10 minute timeout for finalizers
    
    if ! cluster_reachable; then
        log_warning "Cluster not reachable — skipping Helm uninstall for $release in $namespace"
        return 0
    fi
    
    if helm_release_exists "$release" "$namespace"; then
        log_helm "Uninstalling Helm release $release in namespace $namespace (timeout: $timeout)"
        if run_logged "$log_file" helm uninstall "$release" --namespace "$namespace" --wait --timeout "$timeout"; then
            log_helm "Uninstalled $release successfully"
        else
            log_warning "Helm uninstall $release failed; continuing (non-fatal)"
        fi
    else
        log_info "Helm release $release not found in $namespace — skipping uninstall"
    fi
    
    return 0
}

# Safely configure EKS kubeconfig with error handling
safe_eks_kubeconfig() {
    local cluster="$1"
    local region="${2:-$AWS_REGION}"
    
    if ! safe_describe_eks "$cluster" "$region"; then
        log_warning "EKS cluster $cluster not found in region $region — skipping kubeconfig setup"
        return 1
    fi
    
    log_helm "Configuring EKS kubeconfig for cluster $cluster"
    if run_logged "$HELM_LOG_FILE" aws eks update-kubeconfig --name "$cluster" --region "$region" --alias "$cluster"; then
        log_helm "EKS kubeconfig configured successfully"
        return 0
    else
        log_warning "Failed to configure EKS kubeconfig for $cluster"
        return 1
    fi
}

# Check if kubeconfig file exists and is readable
kubeconfig_exists() {
    local kubeconfig_file="$1"
    
    if [[ -f "$kubeconfig_file" && -r "$kubeconfig_file" ]]; then
        return 0
    else
        return 1
    fi
}

# Safely export kubeconfig with validation
safe_export_kubeconfig() {
    local kubeconfig_file="$1"
    
    if ! kubeconfig_exists "$kubeconfig_file"; then
        log_warning "Kubeconfig file not found: $kubeconfig_file — skipping export"
        return 1
    fi
    
    if export KUBECONFIG="$kubeconfig_file"; then
        log_helm "Using kubeconfig: $kubeconfig_file"
        return 0
    else
        log_warning "Failed to export kubeconfig: $kubeconfig_file"
        return 1
    fi
}

# Log cluster status for debugging
log_cluster_status() {
    local cluster_name="$1"
    local context_name="${2:-$cluster_name}"
    
    log_info "=== Cluster Status Debug ==="
    log_info "Cluster: $cluster_name"
    log_info "Current KUBECONFIG: ${KUBECONFIG:-default}"
    
    if kubectl config current-context 2>/dev/null; then
        log_info "Current context: $(kubectl config current-context 2>/dev/null || echo 'unknown')"
    else
        log_warning "No current kubectl context"
    fi
    
    if cluster_reachable; then
        log_info "Cluster is reachable"
        local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
        log_info "Node count: $node_count"
    else
        log_warning "Cluster is not reachable"
    fi
    log_info "=== End Cluster Status ==="
}