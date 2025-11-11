#!/bin/bash
# operations/validate.sh
# Validate Helm chart structure and configuration
# This file is sourced by manage-project.sh

validate-charts() {
    print_log_locations

    log "=== GitOps Repository Validation ==="

    local gitops_root="$GITOPS_DIR"
    if [[ -z "$gitops_root" || ! -d "$gitops_root" ]]; then
        log "❌ GitOps directory not found: ${gitops_root:-unset}"
        return 1
    fi

    log "✅ GitOps directory: $gitops_root"

    log ""
    log "=== Required Manifests ==="
    local required_files=(
        "applications/argocd-config.yaml"
    "applications/quiz-backend.yaml"
    "applications/quiz-frontend.yaml"
        "applications/aws-load-balancer-controller.yaml"
        "applications/external-secrets.yaml"
    "quiz-backend/values.yaml"
    "quiz-frontend/values.yaml"
        "argocd/argocd-targetgroupbinding.yaml"
    )

    local missing=()
    for file in "${required_files[@]}"; do
        if [[ -f "$gitops_root/$file" ]]; then
            log "✅ $file"
        else
            log "❌ Missing: $file"
            missing+=("$file")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR: Missing GitOps manifests: ${missing[*]}"
        return 1
    fi

    log ""
    log "=== Terraform Injection Markers ==="
    local injected_files=(
        "$gitops_root/quiz-backend/values.yaml"
        "$gitops_root/quiz-frontend/values.yaml"
        "$gitops_root/argocd/argocd-targetgroupbinding.yaml"
    )

    for file in "${injected_files[@]}"; do
        if grep -q "# Injected by Terraform" "$file" 2>/dev/null; then
            log "✅ Terraform placeholders present in $(basename "$file")"
        else
            log "⚠️  No Terraform injection markers in $(basename "$file"). Ensure apply has been run."
        fi
    done

    log ""
    log "=== Directory Summary ==="
    find "$gitops_root" -maxdepth 1 -type d -printf " - %f\n" | sort | while read -r dir; do
        [[ "$dir" == "." ]] && continue
        log "${dir}"
    done

    log ""
    log "✅ GitOps validation complete"
}
