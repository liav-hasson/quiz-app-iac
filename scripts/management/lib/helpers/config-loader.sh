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
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-devops-quiz-eks}"

### Scripts ###
PREFLIGHT_CHECK_SCRIPT="${PREFLIGHT_CHECK_SCRIPT:-$LIB_DIR/bootstrap/preflight-check.sh}"
BACKUP_JENKINS_AMI_SCRIPT="$LIB_DIR/cleanup/backup-jenkins-ami.sh"

### Mark as loaded ###
CONFIG_LOADER_SOURCED=1

### Export shared variables ###
export PROJECT_ROOT TERRAFORM_DIR GITOPS_DIR
export LOG_DIR MAIN_LOG_FILE TERRAFORM_LOG_FILE HELM_LOG_FILE ARGOCD_LOG_FILE BOOTSTRAP_LOG_FILE
export AWS_REGION EKS_CLUSTER_NAME
export PREFLIGHT_CHECK_SCRIPT BACKUP_JENKINS_AMI_SCRIPT
