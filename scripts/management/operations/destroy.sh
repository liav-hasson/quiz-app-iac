#!/bin/bash
# operations/destroy.sh
# Orchestrates the infrastructure destroy workflow using modular helpers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "$SCRIPT_DIR/../lib/operations" && pwd)"

source "$LIB_ROOT/destroy/functions.sh"

terraform-destroy() {
    destroy_execute
}
