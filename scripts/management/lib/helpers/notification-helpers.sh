#!/bin/bash
# notification-helpers.sh
# Wrapper functions for deployment notifications
# This file is sourced by manage-project.sh

# Helper function to send notifications via notify-status.sh
apply_stream_notify() {
    local mode="$1"        # start or end
    local operation="$2"   # apply or destroy
    local exit_code="${3:-0}"
    local failed_step="${4:-}"

    "$LIB_DIR/notify-status.sh" "$mode" "$operation" "$exit_code" "$failed_step" || true
}

# Helper function to handle failure notifications and exit
handle_failure() {
    local operation="$1"
    local exit_code="$2"
    local failed_step="$3"

    while IFS= read -r line; do
        [[ -n "$line" ]] && log_message "$line"
    done < <("$LIB_DIR/notify-status.sh" end "$operation" "$exit_code" "$failed_step")
    exit "$exit_code"
}

