#!/bin/bash
# operations/validate.sh
# Validate Helm chart structure and configuration
# This file is sourced by manage-project.sh

validate-charts() {
    print_log_locations
    
    log "=== Validating New Helm Chart Structure ==="
    
    # Check if new charts exist
    local charts=("bootstrap-dev" "bootstrap-prod" "platform-dev" "weather-deployment")
    local missing_charts=()
    
    for chart in "${charts[@]}"; do
        if [[ -d "$PROJECT_ROOT/argocd-repo/$chart" ]]; then
            log "✅ $chart chart found"
        else
            log "❌ $chart chart missing"
            missing_charts+=("$chart")
        fi
    done
    
    if [[ ${#missing_charts[@]} -gt 0 ]]; then
        log "ERROR: Missing charts: ${missing_charts[*]}"
        return 1
    fi
    
    # Check Helm chart dependencies
    log ""
    log "=== Checking Helm Dependencies ==="
    
    log "-> bootstrap-dev dependencies:"
    (cd "$BOOTSTRAP_DEV_CHART_DIR" && run_logged "$HELM_LOG_FILE" helm dependency list)
    
    log "-> bootstrap-prod dependencies:"  
    (cd "$BOOTSTRAP_PROD_CHART_DIR" && run_logged "$HELM_LOG_FILE" helm dependency list)
    
    # Check ArgoCD applications
    log ""
    log "=== Checking ArgoCD Applications ==="
    local applications_dir="$PROJECT_ROOT/argocd-repo/applications"
    if [[ -d "$applications_dir" ]]; then
        log "✅ Applications directory found"
        ls -la "$applications_dir"/*.yaml 2>&1 | tee -a "$ARGOCD_LOG_FILE" "$MAIN_LOG_FILE" || log "No application manifests found"
    else
        log "❌ Applications directory missing"
    fi
    
    # Check central config integration
    log ""
    log "=== Checking Central Config Integration ==="
    log "GitLab Hostname: $GITLAB_HOSTNAME"
    log "Jenkins Hostname: $JENKINS_HOSTNAME"
    log "Jenkins Namespace: $JENKINS_NAMESPACE"
    
    log ""
    log "=== Checking Helm Chart Configuration (GitOps Approach) ==="
    log "Bootstrap Dev:"
    log "  - Cluster Name: $BOOTSTRAP_DEV_CLUSTER_NAME"
    log "  - Chart Dir: $BOOTSTRAP_DEV_CHART_DIR"
    log "  - Namespace: $BOOTSTRAP_DEV_NAMESPACE"
    log "  - All ALB/ArgoCD config is static in bootstrap-dev/values.yaml"
    
    log "Bootstrap Prod:"
    log "  - Cluster Name: $BOOTSTRAP_PROD_CLUSTER_NAME"
    log "  - Chart Dir: $BOOTSTRAP_PROD_CHART_DIR"
    log "  - Namespace: $BOOTSTRAP_PROD_NAMESPACE"
    log "  - All ALB/External Secrets config is static in bootstrap-prod/values.yaml"
    
    log ""
    log "✅ Chart structure validation complete!"
    log ""
    log "📊 Log files available at:"
    log "  - Main log: $MAIN_LOG_FILE"
    log "  - Helm: $HELM_LOG_FILE"
    log "  - ArgoCD: $ARGOCD_LOG_FILE"
    log ""
}
