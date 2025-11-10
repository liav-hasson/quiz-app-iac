#!/bin/bash

### PREFLIGHT DEPENDENCY CHECK SCRIPT ###
#
# Purpose: Validate all required dependencies are available before running manage-project.sh
# Usage: Run before any infrastructure operations to ensure environment is properly configured  
# Note: This script only checks dependencies, it does not install anything
# Dependencies are parsed dynamically from configs/project-dependencies.txt (simplified format)

set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The script lives in: Leumi-project/quiz-app/iac/scripts/management/lib/bootstrap
# Workspace root is six levels up from this file to reach Leumi-project/
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"
DEPS_FILE="$WORKSPACE_ROOT/configs/project-dependencies.txt"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for summary
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Dependency parsing functions
parse_section() {
    local section="$1"
    if [[ ! -f "$DEPS_FILE" ]]; then
        echo "Warning: Dependencies file not found at $DEPS_FILE" >&2
        return 1
    fi
    
    # Extract lines between section header and next ## or end of file
    # Use || true to prevent grep from causing script exit when section is empty
    sed -n "/^## $section/,/^##/p" "$DEPS_FILE" | \
    grep -v '^##' | \
    grep -v '^$' | \
    grep -v '^-' | \
    sed 's/^[[:space:]]*//' | \
    grep -v '^[[:space:]]*$' || true
}



# Helper functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}☀️  WeatherLabs Preflight Check${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_summary() {
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  📝 Preflight Check Summary${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    echo -e "Total checks:    $TOTAL_CHECKS"
    echo -e "${GREEN}Passed:          $PASSED_CHECKS${NC}"
    echo -e "${RED}Failed:          $FAILED_CHECKS${NC}"
    echo -e "${YELLOW}Warnings:        $WARNING_CHECKS${NC}"
    echo
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "${RED}❌ Preflight check FAILED. Please install missing dependencies.${NC}"
        exit 1
    elif [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Preflight check completed with warnings. Some optional tools are missing.${NC}"
        exit 0
    else
        echo -e "${GREEN}✓ All preflight checks PASSED. Proceeding with operation${NC}"
        exit 0
    fi
}

check_command() {
    local cmd="$1"
    local description="$2"
    local required="${3:-true}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if command -v "$cmd" >/dev/null 2>&1; then
        if [ "$required" = "true" ]; then
            echo -e "${GREEN}✓${NC} $description: ${GREEN}found${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${GREEN}✓${NC} $description: ${GREEN}found${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} $description: ${RED}missing${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${YELLOW}⚠${NC} $description: ${YELLOW}missing (optional)${NC}"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
        fi
    fi
}

check_python_module() {
    local module="$1"
    local description="$2"
    local required="${3:-true}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if python3 -c "import $module" >/dev/null 2>&1; then
        if [ "$required" = "true" ]; then
            echo -e "${GREEN}✓${NC} $description: ${GREEN}found${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${GREEN}✓${NC} $description: ${GREEN}found${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} $description: ${RED}missing${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${YELLOW}⚠${NC} $description: ${YELLOW}missing (optional)${NC}"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
        fi
    fi
}


# Main execution
main() {
    print_header
    
    # Check if dependencies file exists
    if [[ ! -f "$DEPS_FILE" ]]; then
        echo -e "${RED}Error: Dependencies file not found at $DEPS_FILE${NC}"
        echo "Please ensure the project-dependencies.txt file exists in the configs directory."
        exit 1
    fi
    
    echo -e "${BLUE}Checking CLI and system tools...${NC}"
    echo
    
    # Parse and check required CLI tools
    local required_tools
    required_tools=$(parse_section "CLI Tools (Required)")
    
    while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        
        check_command "$tool" "$tool" true
    done <<< "$required_tools"
    
    # Parse and check optional CLI tools
    local optional_tools
    optional_tools=$(parse_section "CLI Tools (Optional)")
    
    while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        
        check_command "$tool" "$tool" false
    done <<< "$optional_tools"
    
    echo
    echo -e "${BLUE}Checking Python and virtual environment...${NC}"
    echo
    
    # Check if venv module is available
    check_python_module "venv" "Python venv module" true
    
    echo
    echo -e "${BLUE}Checking Python dependencies...${NC}"
    echo
    
    # Parse and check required Python modules
    local required_modules
    required_modules=$(parse_section "Python Modules (Required)")
    
    while IFS= read -r module; do
        [[ -z "$module" ]] && continue
        
        # Convert some module names for import
        local import_name="$module"
        case "$module" in
            ansible-lint) import_name="ansiblelint" ;;
        esac
        
        check_python_module "$import_name" "$module" true
    done <<< "$required_modules"
    
    # Parse and check optional Python modules
    local optional_modules
    optional_modules=$(parse_section "Python Modules (Optional)")
    
    while IFS= read -r module; do
        [[ -z "$module" ]] && continue
        
        # Convert some module names for import
        local import_name="$module"
        case "$module" in
            ansible-lint) import_name="ansiblelint" ;;
        esac
        
        check_python_module "$import_name" "$module" false
    done <<< "$optional_modules"
    
    print_summary
}

main