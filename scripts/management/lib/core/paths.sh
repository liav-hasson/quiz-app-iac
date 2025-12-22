#!/bin/bash
# paths.sh
# Single source of truth for all path resolution and global configuration.
# Source this file FIRST in any script that needs project paths.

# Guard against double-loading
[[ -n "${_PATHS_LOADED:-}" ]] && return 0
_PATHS_LOADED=1

# =============================================================================
# Core Path Resolution
# =============================================================================
# All paths are resolved relative to this file's location.
# This file lives at: scripts/management/lib/core/paths.sh

_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_CORE_DIR/.." && pwd)"
_MANAGEMENT_DIR="$(cd "$_LIB_DIR/.." && pwd)"
_SCRIPTS_DIR="$(cd "$_MANAGEMENT_DIR/.." && pwd)"
_IAC_DIR="$(cd "$_SCRIPTS_DIR/.." && pwd)"
_PROJECT_ROOT="$(cd "$_IAC_DIR/.." && pwd)"

# =============================================================================
# Exported Path Variables
# =============================================================================

# Project structure
readonly PROJECT_ROOT="$_PROJECT_ROOT"
readonly IAC_DIR="$_IAC_DIR"
readonly SCRIPTS_DIR="$_SCRIPTS_DIR"
readonly MANAGEMENT_DIR="$_MANAGEMENT_DIR"
readonly LIB_DIR="$_LIB_DIR"

# Key directories
readonly TERRAFORM_DIR="$IAC_DIR/terraform"
readonly GITOPS_DIR="$PROJECT_ROOT/gitops"
readonly CONFIGS_DIR="$IAC_DIR/configs"

# Script directories
readonly CORE_DIR="$LIB_DIR/core"
readonly HELPERS_DIR="$LIB_DIR/helpers"
readonly WORKFLOWS_DIR="$LIB_DIR/workflows"
readonly TASKS_DIR="$LIB_DIR/tasks"
readonly TOOLS_DIR="$LIB_DIR/tools"
readonly BIN_DIR="$MANAGEMENT_DIR/bin"

# =============================================================================
# Logging Configuration
# =============================================================================

readonly LOG_DIR="${LOG_DIR:-/tmp/quiz-app-deploy}"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Single log file - all components write here
readonly LOG_FILE="$LOG_DIR/deploy.log"

# =============================================================================
# AWS / EKS Configuration
# =============================================================================

readonly AWS_REGION="${AWS_REGION:-eu-north-1}"
readonly EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-devops-quiz-eks}"

# =============================================================================
# DNS Configuration
# =============================================================================

# Subdomains that point to Istio NLB
readonly DNS_SUBDOMAINS=(
    "quiz"
    "quiz-dev"
    "argocd"
    "jenkins"
    "grafana"
    "loki"
    "kiali"
)

# Default hostnames (can be overridden by Terraform outputs)
readonly DEFAULT_QUIZ_HOST="quiz.weatherlabs.org"
readonly DEFAULT_ARGOCD_HOST="argocd.weatherlabs.org"
readonly DEFAULT_JENKINS_HOST="jenkins.weatherlabs.org"

# =============================================================================
# Export all variables
# =============================================================================

export PROJECT_ROOT IAC_DIR SCRIPTS_DIR MANAGEMENT_DIR LIB_DIR
export TERRAFORM_DIR GITOPS_DIR CONFIGS_DIR
export CORE_DIR HELPERS_DIR WORKFLOWS_DIR TASKS_DIR TOOLS_DIR BIN_DIR
export LOG_DIR LOG_FILE
export AWS_REGION EKS_CLUSTER_NAME
export DNS_SUBDOMAINS
export DEFAULT_QUIZ_HOST DEFAULT_ARGOCD_HOST DEFAULT_JENKINS_HOST
