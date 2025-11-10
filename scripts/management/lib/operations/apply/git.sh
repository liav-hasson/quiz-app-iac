#!/bin/bash

set -euo pipefail

apply_git_precheck() {
    # Git repo is at Leumi-project/ (two levels up from PROJECT_ROOT which is quiz-app/iac)
    local repo="$(cd "$PROJECT_ROOT/../.." && pwd)"
    log_info "Validating repository state: $repo"
    
    check_git_repo_status "$repo" && {
        log_success "Repository clean"
        return 0
    }

    log_warning "Repository has pending changes"
    prompt_for_deferred_push "$repo" || log_warning "Automated git commit/push skipped"
}

apply_commit_injection_changes() {
    # Automatically commit and push GitOps injection changes
    local repo="$(cd "$PROJECT_ROOT/../.." && pwd)"
    
    cd "$repo" || return 1
    
    # Check if there are changes in gitops directory
    if git diff --quiet quiz-app/gitops/ && git diff --cached --quiet quiz-app/gitops/ && [[ -z "$(git status --porcelain quiz-app/gitops/)" ]]; then
        log_info "No GitOps changes to commit"
        return 0
    fi
    
    log_info "GitOps injection changes detected"
    git status --short quiz-app/gitops/ | head -5
    
    # Stage and commit GitOps changes
    git add quiz-app/gitops/
    local commit_msg="auto commit: injecting Terraform outputs into GitOps manifests"
    git commit -m "$commit_msg"
    
    # Pull latest changes (Jenkins may have pushed image tag updates)
    log_info "Pulling latest changes from remote..."
    if ! git pull --rebase origin main; then
        log_error "Failed to rebase on remote changes"
        log_warning "Resolve conflicts manually: cd $repo && git rebase --continue"
        return 1
    fi
    
    # Push automatically
    log_info "Pushing GitOps changes to remote..."
    if git push; then
        log_success "✓ GitOps changes pushed"
        return 0
    else
        log_error "Failed to push GitOps changes"
        log_warning "You must push manually: cd $repo && git push"
        return 1
    fi
}

apply_push_deferred_changes() {
    # Push from main repository root
    local repo="$(cd "$PROJECT_ROOT/../.." && pwd)"
    execute_deferred_push "$repo" || log_warning "Deferred git push skipped"
}
