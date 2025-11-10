#!/bin/bash

set -euo pipefail

apply_execute() {
    local operation="apply"

    # Source: management/lib/helpers/logging-helpers.sh
    print_log_locations

    # Source: management/lib/helpers/validation-helpers.sh
    run_preflight_check "apply operation"
    
    # Check git repository status and prompt for commit/push if needed
    # Source: lib/helpers/git-helpers.sh
    apply_git_precheck

    # sends start slack message 
    # Source: management/lib/helpers/notification-helpers.sh
    apply_stream_notify start "$operation" || true

    # Provision infrastructure with Terraform (VPC, EKS, EC2, Jenkins, IAM roles, ALB)
    # Source: lib/operations/apply/terraform.sh
    apply_run_terraform "$operation"
    
    # Configure kubectl access to production EKS cluster
    # Source: lib/operations/apply/terraform.sh
    apply_configure_prod_cluster "$operation"
    
    # Inject Terraform outputs (IRSA ARNs, ACM cert) into GitOps manifests
    # Source: lib/operations/apply/inject-argocd-values.sh
    inject_terraform_values "$operation"
    
    # Commit and push GitOps injection changes
    # Source: lib/operations/apply/git.sh
    apply_commit_injection_changes
    
    # Push any deferred git changes (from git precheck)
    # Source: lib/operations/apply/git.sh
    apply_push_deferred_changes
    
    # Deploy ArgoCD to EKS cluster
    # Source: lib/operations/apply/argocd.sh
    apply_bootstrap_argocd "$operation"
    
    # Deploy ArgoCD applications (controllers + workloads)
    # Source: lib/operations/apply/argocd.sh
    apply_deploy_argocd_applications "$operation"
    
    # Display deployment summary
    # Source: lib/operations/apply/common.sh
    apply_log_summary

    apply_stream_notify end "$operation" 0 || true
}
