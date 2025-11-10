#!/bin/bash
# validation-helpers.sh
# Validation and preflight check functions
# This file is sourced by manage-project.sh

# Run preflight check before any operations
run_preflight_check() {
    # Preflight check is optional for quiz-app (has weather app dependencies)
    # Skip if SKIP_PREFLIGHT is set
    if [[ "${SKIP_PREFLIGHT:-false}" == "true" ]]; then
        echo "Skipping preflight check (SKIP_PREFLIGHT=true)"
        return 0
    fi

    # this calls scripts/management/lib/bootstrap/preflight-check.sh
    if ! "$PREFLIGHT_CHECK_SCRIPT"; then
        echo "⚠️  Preflight check failed - continuing anyway (set SKIP_PREFLIGHT=true to skip)"
        # Don't exit - the check has weather app dependencies
        return 0
    fi
    echo
}
