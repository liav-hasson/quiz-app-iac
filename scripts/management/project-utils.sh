#!/bin/bash

set -euo pipefail

# Utilities Script for EKS Cluster Management
# This script provides various utility functions for cluster access and management

# Dynamic path detection - find project root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

KUBECONFIG_DIR="$PROJECT_ROOT/infrastructure-repo/kubeconfig"

# Load shared configuration and logging
source "$SCRIPT_DIR/lib/helpers/config-loader.sh"
source "$SCRIPT_DIR/lib/helpers/logging-helpers.sh"

# Script paths
SSM_TUNNEL_SCRIPT="$SSM_TUNNELS_SCRIPT"

# Static hostnames (from Helm values) - used for display only
# These match the values in gitops/quiz-app/values.yaml
readonly QUIZ_APP_HOST="${QUIZ_APP_HOST:-quiz.weatherlabs.org}"
readonly ARGOCD_HOST="${ARGOCD_HOST:-argocd.weatherlabs.org}"
readonly JENKINS_INTERNAL_HOST="${JENKINS_INTERNAL_HOST:-jenkins.weatherlabs.internal}"

echo_line() { printf "%s\n" "$*"; }


get_prod_access_info() {
    # Get EKS cluster access info (QUIZ_APP_URL, ARGOCD_PASSWORD)
    # Returns key=value lines: QUIZ_APP_URL, ARGOCD_PASSWORD
    # 
    # Note: ALB is managed by AWS Load Balancer Controller via Ingress resources.
    local quiz_app_url="$QUIZ_APP_HOST"
    local password=""
    
    # Try to get ArgoCD admin password from the cluster (if available)
    # This requires kubectl access to the EKS cluster
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    fi

    # Print key=value lines (callers parse these)
    echo "QUIZ_APP_URL=$quiz_app_url"
    [[ -n "$password" ]] && echo "ARGOCD_PASSWORD=$password"
}

get_jenkins_eks_credentials() {
    # Get Jenkins EKS cluster credentials for Jenkins Kubernetes Cloud configuration
    # Prints formatted output with all required values for Jenkins setup
    # 
    # These values change every time the cluster is destroyed and recreated.
    # You must update Jenkins credentials and Kubernetes Cloud configuration after cluster recreate.
    
    echo_line
    echo_line "================================="
    echo_line "Jenkins EKS Cluster Credentials"
    echo_line "================================="
    echo_line
    
    # Check if kubectl is configured
    if ! kubectl cluster-info &>/dev/null; then
        echo_line "❌ Error: kubectl is not configured or cluster is not accessible"
        echo_line "   Run: aws eks update-kubeconfig --name devops-quiz-eks --region eu-north-1"
        return 1
    fi
    
    # Check if jenkins-token secret exists
    if ! kubectl get secret jenkins-token -n jenkins &>/dev/null; then
        echo_line "❌ Error: jenkins-token secret not found in jenkins namespace"
        echo_line "   Make sure ArgoCD has deployed the jenkins-platform application"
        return 1
    fi
    
    echo_line "1. Jenkins EKS Token (for jenkins-eks-token credential):"
    echo_line "Insert in 'jenkins-eks-token' Secret text credential"
    echo_line "================================================================="
    local token=$(kubectl get secret jenkins-token -n jenkins -o jsonpath='{.data.token}' | base64 -d)
    echo_line "$token"
    echo_line "================================================================="
    echo_line
    
    echo_line "2. Kubernetes API Server URL:"
    echo_line "Insert in Kubernetes Cloud configuration 'Kubernetes URL' field"
    echo_line "================================================================="
    local api_url=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    echo_line "$api_url"
    echo_line "================================================================="
    echo_line
    
    echo_line "3. Kubernetes Server Certificate Key (CA cert):"
    echo_line "Insert in Kubernetes Cloud configuration 'Kubernetes server certificate key' field"
    echo_line "================================================================="
    local ca_cert=$(kubectl get secret jenkins-token -n jenkins -o jsonpath='{.data.ca\.crt}' | base64 -d)
    echo_line "$ca_cert"
    echo_line "================================================================="
}

# Flag: --access | -a
# Display cluster access information
show_cluster_access() {
    log_message "Fetching cluster access information..."
    
    echo_line
    echo_line "================================="
    echo_line "Quiz App DevOps - Cluster Access"
    echo_line "================================="
    echo_line
    echo_line "EKS Cluster Access:"
    echo_line "  Context:     kubectl config use-context $EKS_CLUSTER_NAME"
    echo_line "  Region:      $AWS_REGION"
    echo_line
    echo_line "Application URLs (after ArgoCD deployment):"
    echo_line "  Quiz App:    https://$QUIZ_APP_HOST"
    echo_line "  ArgoCD UI:   https://$ARGOCD_HOST"
    echo_line "  Jenkins UI:  https://jenkins.weatherlabs.org"
    echo_line
    echo_line "Jenkins (Internal VPC Access via SSM):"
    echo_line "  Internal DNS: $JENKINS_INTERNAL_HOST"
    echo_line "  Access:      aws ssm start-session --target <jenkins-instance-id>"
    echo_line
    
    # Get ArgoCD password
    echo_line "ArgoCD Credentials:"
    local password
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        echo_line "  Username: admin"
        if [[ -n "$password" ]]; then
            echo_line "  Password: $password"
        else
            echo_line "  Password: Not available (check ArgoCD deployment)"
        fi
    else
        echo_line "  Status: ArgoCD not deployed yet"
        echo_line "  * Deploy ArgoCD bootstrap manually (see MANUAL_STEPS.md)"
    fi
    echo_line
}

# Flag: --open | -o
# Open web UIs in browser (optional)
# Triggered by: project-utils --open  (or -o)
open_web_uis() {
    log_message "Getting web UI URLs..."
    
    echo_line
    echo_line "================================="
    echo_line "Web UI Access"
    echo_line "================================="
    echo_line
    echo_line "Quiz App, ArgoCD, and Jenkins are accessible via ALB with HTTPS."
    echo_line

    local quiz_url="https://$QUIZ_APP_HOST"
    local argocd_url="https://$ARGOCD_HOST"
    local jenkins_url="https://jenkins.weatherlabs.org"
    
    echo_line "Quiz App: $quiz_url"
    echo_line "ArgoCD UI: $argocd_url"
    echo_line "Jenkins UI: $jenkins_url"
    echo_line
    
    # Get ArgoCD password
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        local password
        password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        if [[ -n "$password" ]]; then
            echo_line "ArgoCD Credentials:"
            echo_line "  Username: admin"
            echo_line "  Password: $password"
            echo_line
        fi
    fi
    
    echo_line "Opening in browser..."
    if command -v xdg-open &>/dev/null; then
        xdg-open "$quiz_url" 2>/dev/null &
        xdg-open "$argocd_url" 2>/dev/null &
        xdg-open "$jenkins_url" 2>/dev/null &
    elif command -v open &>/dev/null; then
        open "$quiz_url" 2>/dev/null &
        open "$argocd_url" 2>/dev/null &
    else
        echo_line "No browser command found. Please open URLs manually."
    fi
}

# Flag: --gitlab | -g
# Show SSM tunnels status (GitLab SSH and Kubernetes API)
# Triggered by: project-utils --gitlab  (or -g)
show_gitlab_tunnel_status() {
    log_message "Checking SSM tunnels status..."
    
    if [ ! -f "$SSM_TUNNEL_SCRIPT" ]; then
        error "SSM tunnel script not found at $SSM_TUNNEL_SCRIPT"
        return 1
    fi
    
    echo_line
    echo_line "SSM Tunnels Status"
    echo_line "------------------"
    echo_line
    
    # Show current status
    local status_output
    status_output=$("$SSM_TUNNEL_SCRIPT" status 2>&1)
    local status_exit_code=$?
    
    echo_line "$status_output"
    echo_line
    
    # Show management commands
    echo_line "Management Commands:"
    echo_line "  ssm-tunnels start|stop|restart|status [gitlab|kubernetes|all]"
    echo_line
}

# Flag: --argocd | -r
# Manage ArgoCD installation and status
# Triggered by: project-utils --argocd  (or -r)
manage_argocd() {
    log_message "Managing ArgoCD installation..."

    echo_line
    echo_line "================================="
    echo_line "ArgoCD Status"
    echo_line "================================="
    echo_line

    # Check if ArgoCD is already installed
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo_line "✓ ArgoCD namespace exists"
        echo_line

        # Check ArgoCD pods status
        echo_line "ArgoCD Pods Status:"
        kubectl get pods -n argocd --no-headers 2>/dev/null | while read -r line; do
            pod_name=$(echo "$line" | awk '{print $1}')
            pod_status=$(echo "$line" | awk '{print $3}')
            echo_line "  $pod_name: $pod_status"
        done

        # Show access information
        echo_line
        echo_line "ArgoCD Access:"
        echo_line "  URL: https://$ARGOCD_HOST"
        echo_line "  Username: admin"
        local password
        password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || true)
        [[ -n "$password" ]] && echo_line "  Password: $password" || echo_line "  Password: Not yet available"
    else
        echo_line "⚠️  ArgoCD not installed"
        echo_line "   Deploy using: helm install -f pipeline/gitops/bootstrap-dev/values.yaml"
    fi

    echo_line
}

# NLB cross-zone configuration removed - ALB handles cross-zone automatically

# Flag: --help | -h
# Show help
show_help() {
    echo_line
    echo_line "================================="
    echo_line "Quiz App DevOps - Project Utilities"
    echo_line "================================="
    echo_line
    echo_line "Usage: project-utils [OPTIONS]"
    echo_line
    echo_line "Options:"
    echo_line "  --access,   -a       Show access information (cluster + apps)"
    echo_line "  --argocd,   -r       Show ArgoCD status"
    echo_line "  --jenkins,  -j       Get Jenkins EKS credentials for Kubernetes Cloud"
    echo_line "  --open,     -o       Open web UIs in browser"
    echo_line "  --help,     -h       Show this help"
    echo_line
}

# Main function
main() {
    case "${1:-help}" in
        "--access"|"-a")
            show_cluster_access
            ;;
        "--argocd"|"-r")
            manage_argocd
            ;;
        "--jenkins"|"-j")
            get_jenkins_eks_credentials
            ;;
        "--open"|"-o")
            open_web_uis
            ;;
        "--help"|"-h"|"help")
            show_help
            ;;
        *)
            echo_line "Unknown option: ${1:-}"
            echo_line "Use --help or -h to see available options"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
