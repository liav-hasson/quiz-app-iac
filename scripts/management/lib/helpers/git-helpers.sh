#!/usr/bin/env bash
set -euo pipefail

# git-helpers.sh
# Reusable git helper functions for interactive commits and pushes
# Used by quiz-app infrastructure management scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PROJECT_ROOT is quiz-app/iac, repository root is two levels up (Leumi-project/)
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../../../" && pwd)}"
REPO_ROOT="$(cd "$PROJECT_ROOT/../.." && pwd)"


# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


# Lightweight logging shim: prefer central logger if available
_gh_log() {
    local msg="${1:-}"
    if declare -F log_message >/dev/null 2>&1; then
        log_message "$msg"
    else
        echo "$msg"
    fi
}

# check_git_repo_status <repo_dir>
# check_git_repo_status <repo_dir>
# Returns: 0 if clean (no uncommitted changes AND no unpushed commits), 1 if changes exist, 2 if not a git repo
check_git_repo_status() {
    local repo_dir="${1:-$REPO_ROOT}"
    if [[ ! -d "$repo_dir/.git" ]]; then
        _gh_log "[git-helpers] Not a git repo: $repo_dir"
        return 2
    fi

    pushd "$repo_dir" >/dev/null
    
    # Check for uncommitted changes (staged or unstaged)
    local status
    status=$(git status --porcelain 2>/dev/null || true)
    
    # Check for unpushed commits
    local unpushed
    unpushed=$(git log @{u}.. --oneline 2>/dev/null | wc -l || echo "0")
    
    popd >/dev/null

    if [[ -z "$status" && "$unpushed" -eq 0 ]]; then
        return 0
    fi

    return 1
}

# get_current_branch <repo_dir>
get_current_branch() {
    local repo_dir="${1:-$REPO_ROOT}"
    pushd "$repo_dir" >/dev/null
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    popd >/dev/null
    echo "$branch"
}

# commit_and_push_changes <repo_dir> <commit_message> [branch]
# Commits all changes and pushes to 'origin'
commit_and_push_changes() {
    local repo_dir="${1:-$REPO_ROOT}"
    local commit_msg="${2:-"chore: update configs"}"
    local branch="${3:-$(get_current_branch "$repo_dir")}"

    if [[ ! -d "$repo_dir/.git" ]]; then
        echo "[git-helpers] Not a git repo: $repo_dir" >&2
        return 2
    fi

    pushd "$repo_dir" >/dev/null
    # Stage everything relevant and commit if there are changes
    git add -A
    if git diff --cached --quiet; then
        _gh_log "[git-helpers] No changes to commit in $repo_dir"
        popd >/dev/null
        return 0
    fi

    git commit -m "$commit_msg"

    # Push to origin
    _gh_log "[git-helpers] Pushing branch '$branch' to 'origin'"
    git push origin "$branch"
    local rc=$?
    popd >/dev/null
    return $rc
}
# prompt_for_deferred_push <repo_dir>
# Shows status and prompts to commit now, push later (for workflows where push happens after deployment)
# Sets global variables: SHOULD_PUSH_AFTER_TUNNEL, GIT_COMMIT_MESSAGE
# Returns: 0 on success, 1 on error, 2 if not a git repo
prompt_for_deferred_push() {
    local repo_dir="${1:-$REPO_ROOT}"
    
    if [[ ! -d "$repo_dir/.git" ]]; then
        _gh_log "[git-helpers] Not a git repo: $repo_dir"
        return 2
    fi

    pushd "$repo_dir" >/dev/null
    
    # Prompt user with colored banner
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} 📊  Git Repository Changes${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    echo -e "${YELLOW}Found uncommitted changes: ${NC}"
    echo
    
    _gh_log "[git-helpers] Repository: $repo_dir"
    _gh_log "----- git status -----"
    git status --short
    _gh_log "----- git diff --stat -----"
    git diff --stat 2>/dev/null || true
    
    # Show unpushed commits
    local unpushed_count
    unpushed_count=$(git log @{u}.. --oneline 2>/dev/null | wc -l || echo "0")
    if [[ "$unpushed_count" -gt 0 ]]; then
        echo ""
        echo "----- unpushed commits -----"
        git log @{u}.. --oneline --decorate 2>/dev/null || true
    fi
    
    # Ask if user wants to commit and push
    read -r -p "Commit and push these changes after deployment? (y/N): " answer
    case "${answer,,}" in
        y|yes)
            # Check if there are uncommitted changes
            if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git status --porcelain)" ]]; then
                local default_msg="chore: automated update"
                read -r -p "Commit message [${default_msg}]: " user_msg
                GIT_COMMIT_MESSAGE="${user_msg:-$default_msg}"
                
                # Stage and commit now, but defer push
                git add -A
                if ! git diff --cached --quiet; then
                    if git commit -m "$GIT_COMMIT_MESSAGE"; then
                        _gh_log "[git-helpers] ✓ Changes committed: $GIT_COMMIT_MESSAGE"
                    else
                        _gh_log "[git-helpers] ❌ Failed to commit changes"
                        popd >/dev/null
                        return 1
                    fi
                else
                    _gh_log "[git-helpers] No changes to commit"
                fi
            fi
            
            # Check if there are commits to push (either just committed or from previous run)
            unpushed_count=$(git log @{u}.. --oneline 2>/dev/null | wc -l || echo "0")
            if [[ "$unpushed_count" -gt 0 ]]; then
                _gh_log "[git-helpers] ℹ️  Will push $unpushed_count commit(s) after deployment completes"
                SHOULD_PUSH_AFTER_TUNNEL=true
            else
                _gh_log "[git-helpers] ⚠️  No commits to push"
            fi
            ;;
        *)
            _gh_log "[git-helpers] Skipping commit/push - you can commit manually later"
            ;;
    esac
    
    popd >/dev/null
    return 0
}

# execute_deferred_push <repo_dir>
# Pushes previously committed changes (controlled by SHOULD_PUSH_AFTER_TUNNEL flag)
# Returns: 0 on success or if nothing to push, 1 on error, 2 if not a git repo
execute_deferred_push() {
    local repo_dir="${1:-$REPO_ROOT}"
    
    if [[ "$SHOULD_PUSH_AFTER_TUNNEL" != "true" ]]; then
        return 0
    fi
    
    if [[ ! -d "$repo_dir/.git" ]]; then
        echo "[git-helpers] Not a git repo: $repo_dir" >&2
        return 2
    fi
    
    _gh_log "[git-helpers] ℹ️  Deployment complete - pushing committed changes"
    
    pushd "$repo_dir" >/dev/null
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    
    _gh_log "[git-helpers] Pushing branch '$branch' to 'origin'"
    if git push origin "$branch"; then
        _gh_log "[git-helpers] ✅ Successfully pushed changes to origin/$branch"
        popd >/dev/null
        return 0
    else
        _gh_log "[git-helpers] ❌ Failed to push changes - you may need to push manually"
        _gh_log "[git-helpers] Run: cd $repo_dir && git push origin $branch"
        popd >/dev/null
        return 1
    fi
}

export -f check_git_repo_status get_current_branch commit_and_push_changes prompt_for_deferred_push execute_deferred_push
