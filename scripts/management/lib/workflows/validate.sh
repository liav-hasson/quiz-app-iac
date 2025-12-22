#!/bin/bash
# workflows/validate.sh
# Validation workflow for configuration, connectivity, and health checks.

# Guard against double-loading
[[ -n "${_WORKFLOW_VALIDATE_LOADED:-}" ]] && return 0
_WORKFLOW_VALIDATE_LOADED=1

# =============================================================================
# Validation Counters
# =============================================================================

_VALIDATE_TOTAL=0
_VALIDATE_PASSED=0
_VALIDATE_FAILED=0
_VALIDATE_WARNINGS=0

_check_pass() {
    _VALIDATE_TOTAL=$((_VALIDATE_TOTAL + 1))
    _VALIDATE_PASSED=$((_VALIDATE_PASSED + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

_check_fail() {
    _VALIDATE_TOTAL=$((_VALIDATE_TOTAL + 1))
    _VALIDATE_FAILED=$((_VALIDATE_FAILED + 1))
    echo -e "${RED}[FAIL]${NC} $1"
}

_check_warn() {
    _VALIDATE_TOTAL=$((_VALIDATE_TOTAL + 1))
    _VALIDATE_WARNINGS=$((_VALIDATE_WARNINGS + 1))
    echo -e "${YELLOW}[WARN]${NC} $1"
}

_check_skip() {
    echo -e "${CYAN}[SKIP]${NC} $1"
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_gitops_structure() {
    echo ""
    echo "GitOps Repository Structure"
    echo "---------------------------"
    
    if [[ ! -d "$GITOPS_DIR" ]]; then
        _check_fail "GitOps directory not found: $GITOPS_DIR"
        return 1
    fi
    _check_pass "GitOps directory exists"
    
    # Required manifests
    local required_files=(
        "apps/platform/aws-load-balancer-controller.yaml"
        "apps/platform/external-secrets.yaml"
        "apps/workloads/quiz-backend.yaml"
        "apps/workloads/quiz-frontend.yaml"
        "charts/workloads/quiz-backend/values.yaml"
        "charts/workloads/quiz-frontend/values.yaml"
        "apps/istio/gateway.yaml"
        "apps/istio/istio-config.yaml"
        "bootstrap/root-app.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$GITOPS_DIR/$file" ]]; then
            _check_pass "$file"
        else
            _check_fail "Missing: $file"
        fi
    done
}

validate_terraform_state() {
    echo ""
    echo "Terraform State"
    echo "---------------"
    
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        _check_fail "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    _check_pass "Terraform directory exists"
    
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        _check_pass "Terraform state file exists"
        
        # Check for key outputs
        local outputs=("eks_cluster_name" "alb_controller_role_arn" "external_secrets_role_arn")
        for output in "${outputs[@]}"; do
            local value
            value=$(cd "$TERRAFORM_DIR" && terraform output -raw "$output" 2>/dev/null || echo "")
            if [[ -n "$value" ]]; then
                _check_pass "Output '$output' is set"
            else
                _check_warn "Output '$output' is empty or missing"
            fi
        done
    else
        _check_warn "Terraform state not found (run 'manage-project --apply' first)"
    fi
}

validate_terraform_injection() {
    echo ""
    echo "Terraform Value Injection"
    echo "-------------------------"
    
    local injection_files=(
        "$GITOPS_DIR/apps/platform/aws-load-balancer-controller.yaml"
        "$GITOPS_DIR/apps/platform/external-secrets.yaml"
        "$GITOPS_DIR/apps/istio/gateway.yaml"
    )
    
    for file in "${injection_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            _check_skip "$(basename "$file") - file not found"
            continue
        fi
        
        if grep -q "# Injected by Terraform" "$file" 2>/dev/null; then
            # Check if it has a real value (not empty)
            if grep -E 'value: "arn:aws' "$file" &>/dev/null; then
                _check_pass "$(basename "$file") - values injected"
            else
                _check_warn "$(basename "$file") - injection marker exists but values may be empty"
            fi
        else
            _check_warn "$(basename "$file") - no injection markers found"
        fi
    done
}

validate_eks_connectivity() {
    echo ""
    echo "EKS Cluster Connectivity"
    echo "------------------------"
    
    # Check if kubectl is configured
    if ! command -v kubectl &>/dev/null; then
        _check_fail "kubectl not found in PATH"
        return 1
    fi
    _check_pass "kubectl is installed"
    
    # Check cluster reachability
    if kubectl cluster-info &>/dev/null; then
        _check_pass "Cluster is reachable"
        
        # Check node count
        local node_count
        node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        if [[ "$node_count" -gt 0 ]]; then
            _check_pass "Cluster has $node_count node(s)"
        else
            _check_warn "No nodes found in cluster"
        fi
        
        # Check current context
        local context
        context=$(kubectl config current-context 2>/dev/null || echo "unknown")
        if [[ "$context" == *"$EKS_CLUSTER_NAME"* ]]; then
            _check_pass "Context matches expected cluster: $context"
        else
            _check_warn "Current context: $context (expected: $EKS_CLUSTER_NAME)"
        fi
    else
        _check_warn "Cluster not reachable (may not be deployed yet)"
    fi
}

validate_argocd_status() {
    echo ""
    echo "ArgoCD Status"
    echo "-------------"
    
    if ! kubectl get namespace argocd &>/dev/null; then
        _check_skip "ArgoCD namespace not found"
        return 0
    fi
    _check_pass "ArgoCD namespace exists"
    
    # Check ArgoCD server pod
    local server_status
    server_status=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    
    if [[ "$server_status" == "Running" ]]; then
        _check_pass "ArgoCD server is running"
    elif [[ -n "$server_status" ]]; then
        _check_warn "ArgoCD server status: $server_status"
    else
        _check_fail "ArgoCD server pod not found"
    fi
    
    # Check applications
    local app_count
    app_count=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    if [[ "$app_count" -gt 0 ]]; then
        _check_pass "$app_count ArgoCD application(s) found"
        
        # Check for unhealthy apps
        local unhealthy
        unhealthy=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.health.status!="Healthy")].metadata.name}' 2>/dev/null)
        if [[ -n "$unhealthy" ]]; then
            _check_warn "Unhealthy applications: $unhealthy"
        fi
    else
        _check_warn "No ArgoCD applications found"
    fi
}

validate_dns_resolution() {
    echo ""
    echo "DNS Resolution"
    echo "--------------"
    
    if ! command -v dig &>/dev/null; then
        _check_skip "dig command not available"
        return 0
    fi
    
    local hosts=("$DEFAULT_QUIZ_HOST" "$DEFAULT_ARGOCD_HOST" "$DEFAULT_JENKINS_HOST")
    
    for host in "${hosts[@]}"; do
        local result
        result=$(dig +short "$host" @8.8.8.8 2>/dev/null | head -1)
        if [[ -n "$result" ]]; then
            _check_pass "$host resolves to $result"
        else
            _check_warn "$host does not resolve (may not be configured yet)"
        fi
    done
}

validate_aws_resources() {
    echo ""
    echo "AWS Resources"
    echo "-------------"
    
    if ! command -v aws &>/dev/null; then
        _check_fail "AWS CLI not found"
        return 1
    fi
    
    # Check EKS cluster
    if aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
        _check_pass "EKS cluster '$EKS_CLUSTER_NAME' exists"
    else
        _check_warn "EKS cluster '$EKS_CLUSTER_NAME' not found"
    fi
    
    # Check for NLB (Istio)
    local nlb_count
    nlb_count=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
        --query "LoadBalancers[?Type=='network'] | length(@)" --output text 2>/dev/null || echo "0")
    if [[ "$nlb_count" -gt 0 ]]; then
        _check_pass "$nlb_count Network Load Balancer(s) found"
    else
        _check_warn "No Network Load Balancers found"
    fi
}

# =============================================================================
# Main Workflow
# =============================================================================

workflow_validate() {
    echo ""
    echo "=========================================="
    echo "       Configuration Validation          "
    echo "=========================================="
    
    # Reset counters
    _VALIDATE_TOTAL=0
    _VALIDATE_PASSED=0
    _VALIDATE_FAILED=0
    _VALIDATE_WARNINGS=0
    
    # Run all validations
    validate_gitops_structure
    validate_terraform_state
    validate_terraform_injection
    validate_eks_connectivity
    validate_argocd_status
    validate_dns_resolution
    validate_aws_resources
    
    # Summary
    echo ""
    echo "=========================================="
    echo "             Summary                      "
    echo "=========================================="
    echo ""
    echo "Total checks:   $_VALIDATE_TOTAL"
    echo -e "${GREEN}Passed:         $_VALIDATE_PASSED${NC}"
    echo -e "${RED}Failed:         $_VALIDATE_FAILED${NC}"
    echo -e "${YELLOW}Warnings:       $_VALIDATE_WARNINGS${NC}"
    echo ""
    
    if [[ $_VALIDATE_FAILED -gt 0 ]]; then
        echo -e "${RED}Validation FAILED${NC}"
        return 1
    elif [[ $_VALIDATE_WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Validation completed with warnings${NC}"
        return 0
    else
        echo -e "${GREEN}All validations passed${NC}"
        return 0
    fi
}
