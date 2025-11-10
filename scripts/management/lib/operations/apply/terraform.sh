#!/bin/bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


# Removed apply_prompt_sudo_password - sudo not needed for terraform

apply_run_terraform() {
    local operation="$1"
    local previous_dir="$PWD"

    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  🛠️  Terraform Deployment${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""

    # Source: lib/helpers/logging.sh
    log_terraform "Initialising Terraform workspace"
    if ! cd "$TERRAFORM_DIR"; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        echo -e "${RED}❌ Terraform directory not found: $TERRAFORM_DIR${NC}"
        return 1
    fi

    # Run terraform init (no sudo needed, logs only to file)
    echo -e "${BLUE}Running terraform init...${NC}"
    if ! run_logged "$TERRAFORM_LOG_FILE" terraform init; then
        log_error "terraform init failed"
        echo -e "${RED}❌ Terraform init failed. Check logs: $TERRAFORM_LOG_FILE${NC}"
        cd "$previous_dir"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✓ Terraform init successful. Proceeding with infrastructure provisioning.${NC}"
    echo ""
    echo -e "${BLUE}🖥️  To continue monitoring: monitor-deployment -h${NC}"
    echo -e "${YELLOW}⚠️  Don't close this terminal${NC}"
    echo ""
    log_terraform "Terraform initialization completed"

    # Run terraform apply (logs only to file, not terminal)
    log_terraform "Starting terraform apply"
    if ! run_logged "$TERRAFORM_LOG_FILE" terraform apply -auto-approve; then
        log_error "terraform apply failed"
        echo ""
        echo -e "${RED}❌ Terraform apply failed. Check logs: $TERRAFORM_LOG_FILE${NC}"
        cd "$previous_dir"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✓ Terraform apply completed successfully.${NC}"
    # Source: lib/helpers/logging.sh
    log_terraform "Terraform apply completed"
    cd "$previous_dir"
}

apply_configure_prod_cluster() {
    local operation="$1"

    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  ⚙️  EKS Cluster Configuration${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""

    # Source: lib/helpers/logging.sh
    log_helm "Configuring kubectl access to EKS cluster"
    echo -e "${BLUE}Updating kubeconfig for $EKS_CLUSTER_NAME...${NC}"
    
    # Source: lib/helpers/logging.sh
    run_logged "$HELM_LOG_FILE" aws eks update-kubeconfig \
        --name "$EKS_CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --alias "$EKS_CLUSTER_NAME" || {
            # Source: lib/helpers/logging.sh
            log_error "Unable to update kubeconfig for $EKS_CLUSTER_NAME"
            echo -e "${RED}❌ Failed to update kubeconfig${NC}"
            # Source: lib/helpers/error-handler.sh
            handle_failure "$operation" 1 "eks_kubeconfig"
        }

    # Switch kubectl context to EKS cluster
    kubectl config use-context "$EKS_CLUSTER_NAME" || {
        # Source: lib/helpers/logging.sh
        log_error "Failed to switch kubectl context to $EKS_CLUSTER_NAME"
        echo -e "${RED}❌ Failed to switch kubectl context${NC}"
        # Source: lib/helpers/error-handler.sh
        handle_failure "$operation" 1 "eks_context_switch"
    }

    echo -e "${GREEN}✓ Kubectl configured for $EKS_CLUSTER_NAME${NC}"
    # Source: lib/helpers/logging.sh
    log_helm "Kubectl context switched to $EKS_CLUSTER_NAME"

    echo ""
    echo -e "${YELLOW}📋 Cluster configured - ArgoCD and operators managed via GitOps${NC}"
    echo -e "${YELLOW}   Next steps: Run injection script and deploy ArgoCD bootstrap${NC}"
}
