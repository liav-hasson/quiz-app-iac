#!/bin/bash
# tasks/git-sync.sh
# Git operations for syncing GitOps repository changes

# Guard against double-loading
[[ -n "${_TASK_GIT_SYNC_LOADED:-}" ]] && return 0
_TASK_GIT_SYNC_LOADED=1

# =============================================================================
# Commit GitOps Changes
# =============================================================================

task_commit_gitops_changes() {
    log_info "Checking GitOps repository for changes"
    
    if [[ ! -d "$GITOPS_DIR/.git" ]]; then
        log_error "GitOps directory is not a git repository: $GITOPS_DIR"
        return 1
    fi
    
    cd "$GITOPS_DIR" || return 1
    
    # Check if there are any changes
    if git diff --quiet && git diff --cached --quiet && [[ -z "$(git status --porcelain)" ]]; then
        log_info "No GitOps changes to commit"
        return 0
    fi
    
    log_info "GitOps changes detected:"
    git status --short | head -10
    
    # Stage all changes
    git add .
    
    # Commit
    local commit_msg="chore: inject Terraform outputs into GitOps manifests"
    if ! git commit -m "$commit_msg"; then
        log_error "Failed to commit GitOps changes"
        return 1
    fi
    log_info "Changes committed: $commit_msg"
    
    # Pull latest (rebase to handle any concurrent changes)
    log_info "Pulling latest changes from remote..."
    if ! git pull --rebase origin main 2>/dev/null; then
        log_warning "Failed to rebase, trying merge..."
        if ! git pull origin main; then
            log_error "Failed to pull remote changes"
            log_warning "Resolve conflicts manually: cd $GITOPS_DIR && git status"
            return 1
        fi
    fi
    
    # Push
    log_info "Pushing GitOps changes to remote..."
    if ! git push origin main; then
        log_error "Failed to push GitOps changes"
        log_warning "Push manually: cd $GITOPS_DIR && git push"
        return 1
    fi
    
    log_success "GitOps changes pushed to remote"
    return 0
}

# =============================================================================
# Git Status Check
# =============================================================================

task_check_git_status() {
    local repo_dir="${1:-$GITOPS_DIR}"
    
    if [[ ! -d "$repo_dir/.git" ]]; then
        log_debug "Not a git repository: $repo_dir"
        return 2
    fi
    
    cd "$repo_dir" || return 1
    
    # Check for uncommitted changes
    local status
    status=$(git status --porcelain 2>/dev/null || true)
    
    # Check for unpushed commits
    local unpushed
    unpushed=$(git log @{u}.. --oneline 2>/dev/null | wc -l || echo "0")
    
    if [[ -z "$status" && "$unpushed" -eq 0 ]]; then
        return 0  # Clean
    fi
    
    return 1  # Has changes
}

# =============================================================================
# Get Current Branch
# =============================================================================

task_get_current_branch() {
    local repo_dir="${1:-$GITOPS_DIR}"
    
    cd "$repo_dir" 2>/dev/null || {
        echo "main"
        return
    }
    
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
}
