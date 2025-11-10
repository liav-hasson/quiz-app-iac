#!/bin/bash
# config-loader.sh
# Centralised configuration loader for management scripts.
# Prerequisites: SCRIPT_DIR and PROJECT_ROOT must be set before sourcing.

# Guard against double-loading with incompatible roots
if [[ -n "${CONFIG_LOADER_SOURCED:-}" ]]; then
    return 0
fi

### Core Path Variables ###
SCRIPTS_ROOT="${SCRIPTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MANAGEMENT_DIR="$SCRIPTS_ROOT"
LIB_DIR="$MANAGEMENT_DIR/lib"
PROJECT_ROOT="$(cd "$SCRIPTS_ROOT/../../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/iac/terraform"
GITOPS_DIR="$PROJECT_ROOT/gitops"

### Logging Configuration ###
LOG_DIR="${LOG_DIR:-/tmp/quiz-app-deploy}"
# Note: Using /tmp for logs - fixed names for easy monitoring

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Fixed log file names (no timestamps) for easy monitoring with tail -f
MAIN_LOG_FILE="$LOG_DIR/manage-project.log"
TERRAFORM_LOG_FILE="$LOG_DIR/terraform.log"
HELM_LOG_FILE="$LOG_DIR/helm.log"
ARGOCD_LOG_FILE="$LOG_DIR/argocd.log"
BOOTSTRAP_LOG_FILE="$LOG_DIR/bootstrap.log"

# Timestamp for display purposes only
LOG_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

### Global Configuration ###
AWS_REGION="${AWS_REGION:-eu-north-1}"
GLOBAL_REGION="$AWS_REGION"

### Cluster Configuration ###
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-devops-quiz-eks}"
BOOTSTRAP_PROD_CLUSTER_NAME="$EKS_CLUSTER_NAME"

### Namespaces ###
ARGOCD_NAMESPACE="argocd"
ALB_CONTROLLER_NAMESPACE="kube-system"
EXTERNAL_SECRETS_NAMESPACE="external-secrets-system"
QUIZ_APP_NAMESPACE="quiz-app"

### Helm Chart Configuration (used for reference only - ArgoCD manages these) ###
ARGOCD_CHART_REPO="https://argoproj.github.io/argo-helm"
ARGOCD_CHART_NAME="argo-cd"
ARGOCD_CHART_VERSION="7.5.2"
ARGOCD_RELEASE_NAME="argocd"

ALB_CONTROLLER_CHART_REPO="https://aws.github.io/eks-charts"
ALB_CONTROLLER_CHART_NAME="aws-load-balancer-controller"
ALB_CONTROLLER_CHART_VERSION="1.8.1"
ALB_CONTROLLER_RELEASE_NAME="aws-load-balancer-controller"

EXTERNAL_SECRETS_CHART_REPO="https://charts.external-secrets.io"
EXTERNAL_SECRETS_CHART_NAME="external-secrets"
EXTERNAL_SECRETS_CHART_VERSION="0.9.20"
EXTERNAL_SECRETS_RELEASE_NAME="external-secrets"

### Preflight Check Script ###
PREFLIGHT_CHECK_SCRIPT="${PREFLIGHT_CHECK_SCRIPT:-$LIB_DIR/bootstrap/preflight-check.sh}"
SSM_TUNNELS_SCRIPT="/dev/null"  # Not used
BACKUP_AMI_SCRIPT="/dev/null"   # Not used

### Mark as loaded ###
CONFIG_LOADER_SOURCED=1

### Export shared variables ###
export PROJECT_ROOT TERRAFORM_DIR GITOPS_DIR
export LOG_DIR MAIN_LOG_FILE TERRAFORM_LOG_FILE HELM_LOG_FILE ARGOCD_LOG_FILE BOOTSTRAP_LOG_FILE
export AWS_REGION GLOBAL_REGION EKS_CLUSTER_NAME
export ARGOCD_NAMESPACE ALB_CONTROLLER_NAMESPACE EXTERNAL_SECRETS_NAMESPACE QUIZ_APP_NAMESPACE
export ARGOCD_CHART_REPO ARGOCD_CHART_NAME ARGOCD_CHART_VERSION ARGOCD_RELEASE_NAME
export ALB_CONTROLLER_CHART_REPO ALB_CONTROLLER_CHART_NAME ALB_CONTROLLER_CHART_VERSION ALB_CONTROLLER_RELEASE_NAME
export EXTERNAL_SECRETS_CHART_REPO EXTERNAL_SECRETS_CHART_NAME EXTERNAL_SECRETS_CHART_VERSION EXTERNAL_SECRETS_RELEASE_NAME
export PREFLIGHT_CHECK_SCRIPT
