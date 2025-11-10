#!/bin/bash

### INFRASTRUCTURE PROVISIONING + CONFIGURATION SCRIPT ###
# 
## Purpose: Deploy and manage Quiz App infrastructure on AWS EKS
## Function: Runs terraform to provision infrastructure, then configures GitOps deployment
## 
## This is the main entry point that sources modular libraries and operations


### Core Path Variables ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source Library Modules
# Load helper functions (absolute paths from project root)
source "$SCRIPT_DIR/lib/helpers/config-loader.sh"
source "$SCRIPT_DIR/lib/helpers/logging-helpers.sh"
source "$SCRIPT_DIR/lib/helpers/kube-helpers.sh"
source "$SCRIPT_DIR/lib/helpers/notification-helpers.sh"
# Note: ArgoCD now manages application deployments via GitOps

### Main Execution ###
case "${1:-help}" in
    "--apply"|"-a")
        echo "Starting apply; logs: $LOG_DIR"
        # Load and execute apply operation
        source "$SCRIPT_DIR/operations/apply.sh"
        terraform-apply
        ;;
    "--destroy"|"-d")
        echo "Starting destroy; logs: $LOG_DIR"
        # Load and execute destroy operation
        source "$SCRIPT_DIR/operations/destroy.sh"
        terraform-destroy
        ;;
    "--validate"|"-v")
        # Load and execute validate operation
        source "$SCRIPT_DIR/operations/validate.sh"
        validate-charts
        ;;
    *)
        echo "Usage: manage-project {apply|destroy|validate}"
        echo ""
        echo "Commands:"
        echo "  --apply,    -a     - Deploy infrastructure and configure GitOps"
        echo "  --destroy,  -d     - Tear down all infrastructure"
        echo "  --validate, -v     - Validate Helm chart structure and configuration"
        echo ""
        echo "Infrastructure: EKS cluster, Jenkins, ALB, Route53, ArgoCD, Quiz App"
        exit 1
        ;;
esac
