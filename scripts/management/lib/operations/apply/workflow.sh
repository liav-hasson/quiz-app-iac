#!/bin/bash

set -euo pipefail

apply_execute() {
    local operation="apply"

    # Source: management/lib/helpers/logging-helpers.sh
    print_log_locations

    # Source: management/lib/helpers/validation-helpers.sh
    run_preflight_check "apply operation"

    # sends start slack message 
    # Source: management/lib/helpers/notification-helpers.sh
    apply_stream_notify start "$operation" || true

    # Provision infrastructure with Terraform (VPC, EKS, EC2, Jenkins, IAM roles, ALB)
    # Source: lib/operations/apply/terraform.sh
    apply_run_terraform "$operation"
    
    # Configure kubectl access to production EKS cluster
    # Source: lib/operations/apply/terraform.sh
    apply_configure_prod_cluster "$operation"
    
    # Inject ESO IRSA role ARN (bootstrap requirement)
    # Source: lib/operations/apply/inject-eso-role.sh
    apply_inject_eso_role
    
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
