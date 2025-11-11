#!/bin/bash

set -euo pipefail

apply_git_precheck() {
    # GitOps is its own separate repository
    local gitops_repo="$GITOPS_DIR"
    log_info "Validating GitOps repository state: $gitops_repo"
    
    check_git_repo_status "$gitops_repo" && {
        log_success "GitOps repository clean"
        return 0
    }

    log_warning "GitOps repository has pending changes"
    prompt_for_deferred_push "$gitops_repo" || log_warning "Automated git commit/push skipped"
}

apply_commit_injection_changes() {
    # Automatically commit and push GitOps injection changes
    # GitOps is its own separate repository
    local gitops_repo="$GITOPS_DIR"
    
    cd "$gitops_repo" || return 1
    
    # Check if there are changes in the gitops repository
    if git diff --quiet && git diff --cached --quiet && [[ -z "$(git status --porcelain)" ]]; then
        log_info "No GitOps changes to commit"
        return 0
    fi
    
    log_info "GitOps injection changes detected"
    git status --short | head -5
    
    # Stage and commit all GitOps changes
    git add .
    local commit_msg="auto commit: injecting Terraform outputs into GitOps manifests"
    git commit -m "$commit_msg"
    
    # Pull latest changes (Jenkins may have pushed image tag updates)
    log_info "Pulling latest changes from remote..."
    if ! git pull --rebase origin main; then
        log_error "Failed to rebase on remote changes"
        log_warning "Resolve conflicts manually: cd $gitops_repo && git rebase --continue"
        return 1
    fi
    
    # Push automatically
    log_info "Pushing GitOps changes to remote..."
    if git push; then
        log_success "✓ GitOps changes pushed"
        return 0
    else
        log_error "Failed to push GitOps changes"
        log_warning "You must push manually: cd $gitops_repo && git push"
        return 1
    fi
}

apply_push_deferred_changes() {
    # Push from GitOps repository
    local gitops_repo="$GITOPS_DIR"
    execute_deferred_push "$gitops_repo" || log_warning "Deferred git push skipped"
}
