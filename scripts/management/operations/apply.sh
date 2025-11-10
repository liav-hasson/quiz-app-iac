#!/bin/bash
# operations/apply.sh
# Orchestrates the infrastructure apply workflow using modular helpers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source helper scripts FIRST (needed by operation scripts)
source "$LIB_ROOT/helpers/logging-helpers.sh"
source "$LIB_ROOT/helpers/validation-helpers.sh"
source "$LIB_ROOT/helpers/git-helpers.sh"
source "$LIB_ROOT/helpers/notification-helpers.sh"

# Source operation scripts (depend on helpers above)
source "$LIB_ROOT/operations/apply/common.sh"
source "$LIB_ROOT/operations/apply/git.sh"
source "$LIB_ROOT/operations/apply/terraform.sh"
source "$LIB_ROOT/operations/apply/inject-argocd-values.sh"
source "$LIB_ROOT/operations/apply/argocd.sh"
source "$LIB_ROOT/operations/apply/workflow.sh"

# calls bootstrap/operations/apply/workflow.sh
terraform-apply() {
    apply_execute
}
