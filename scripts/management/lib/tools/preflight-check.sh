#!/bin/bash
# tools/preflight-check.sh
# Validate all required dependencies before running operations

# Guard against double-loading
[[ -n "${_TOOL_PREFLIGHT_LOADED:-}" ]] && return 0
_TOOL_PREFLIGHT_LOADED=1

# =============================================================================
# Configuration
# =============================================================================

DEPS_FILE="$CONFIGS_DIR/project-dependencies.txt"

# Counters
_PF_TOTAL=0
_PF_PASSED=0
_PF_FAILED=0
_PF_WARNINGS=0

# =============================================================================
# Check Functions
# =============================================================================

_pf_check_command() {
    local cmd="$1"
    local description="$2"
    local required="${3:-true}"
    
    ((_PF_TOTAL++))
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $description"
        ((_PF_PASSED++))
    else
        if [[ "$required" == "true" ]]; then
            echo -e "${RED}[MISSING]${NC} $description"
            ((_PF_FAILED++))
        else
            echo -e "${YELLOW}[OPTIONAL]${NC} $description"
            ((_PF_WARNINGS++))
        fi
    fi
}

_pf_check_python_module() {
    local module="$1"
    local description="$2"
    local required="${3:-true}"
    
    ((_PF_TOTAL++))
    
    if python3 -c "import $module" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $description"
        ((_PF_PASSED++))
    else
        if [[ "$required" == "true" ]]; then
            echo -e "${RED}[MISSING]${NC} $description"
            ((_PF_FAILED++))
        else
            echo -e "${YELLOW}[OPTIONAL]${NC} $description"
            ((_PF_WARNINGS++))
        fi
    fi
}

_pf_check_aws_auth() {
    ((_PF_TOTAL++))
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} AWS credentials valid"
        ((_PF_PASSED++))
    else
        echo -e "${RED}[FAILED]${NC} AWS credentials not configured or expired"
        ((_PF_FAILED++))
    fi
}

# =============================================================================
# Main Preflight Check
# =============================================================================

run_preflight_check() {
    echo ""
    echo "================================"
    echo "    Preflight Dependency Check  "
    echo "================================"
    echo ""
    
    # Reset counters
    _PF_TOTAL=0
    _PF_PASSED=0
    _PF_FAILED=0
    _PF_WARNINGS=0
    
    # Core CLI tools (required)
    echo "Core CLI Tools:"
    _pf_check_command "aws" "AWS CLI"
    _pf_check_command "terraform" "Terraform"
    _pf_check_command "kubectl" "kubectl"
    _pf_check_command "helm" "Helm"
    _pf_check_command "git" "Git"
    _pf_check_command "jq" "jq (JSON processor)"
    echo ""
    
    # Optional tools
    echo "Optional Tools:"
    _pf_check_command "yq" "yq (YAML processor)" "false"
    _pf_check_command "dig" "dig (DNS lookup)" "false"
    _pf_check_command "curl" "curl" "false"
    echo ""
    
    # AWS authentication
    echo "AWS Authentication:"
    _pf_check_aws_auth
    echo ""
    
    # Python (if needed)
    if command -v python3 >/dev/null 2>&1; then
        echo "Python Environment:"
        _pf_check_command "python3" "Python 3"
        _pf_check_python_module "yaml" "PyYAML" "false"
        _pf_check_python_module "boto3" "boto3" "false"
        echo ""
    fi
    
    # Summary
    echo "================================"
    echo "         Summary                "
    echo "================================"
    echo ""
    echo "Total checks:   $_PF_TOTAL"
    echo -e "${GREEN}Passed:         $_PF_PASSED${NC}"
    echo -e "${RED}Failed:         $_PF_FAILED${NC}"
    echo -e "${YELLOW}Warnings:       $_PF_WARNINGS${NC}"
    echo ""
    
    if [[ $_PF_FAILED -gt 0 ]]; then
        echo -e "${RED}Preflight check FAILED${NC}"
        echo "Please install missing dependencies before continuing."
        return 1
    elif [[ $_PF_WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Preflight check passed with warnings${NC}"
        return 0
    else
        echo -e "${GREEN}All preflight checks passed${NC}"
        return 0
    fi
}
