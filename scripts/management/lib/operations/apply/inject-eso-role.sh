#!/bin/bash

set -euo pipefail

# Inject External Secrets Operator IRSA role ARN into external-secrets Application
# This is the ONLY value that needs injection because it creates a chicken-and-egg:
# - ESO needs the role to access SSM
# - SSM contains all other infrastructure values
# - ESO must deploy before it can fetch from SSM

apply_inject_eso_role() {
    local gitops_dir="${GITOPS_DIR:-/home/liav/github/quiz-app/gitops}"
    local eso_app_file="$gitops_dir/applications/external-secrets.yaml"
    
    log_message "Injecting ESO IRSA role ARN into external-secrets Application..."
    
    # Get ESO role ARN from Terraform
    local eso_role_arn
    eso_role_arn=$(apply_tf_output "external_secrets_role_arn")
    
    if [[ -z "$eso_role_arn" ]]; then
        log_error "Failed to get external_secrets_role_arn from Terraform"
        return 1
    fi
    
    log_message "ESO Role ARN: $eso_role_arn"
    
    # Inject into external-secrets.yaml
    sed -i "s|value: arn:aws:iam::[0-9]*:role/.*-external-secrets-irsa|value: $eso_role_arn|g" "$eso_app_file"
    
    log_message "✓ ESO role ARN injected successfully"
    
    # Commit and push changes to Git
    log_message "Committing ESO role ARN to Git..."
    
    cd "$gitops_dir" || {
        log_error "Failed to change to gitops directory: $gitops_dir"
        return 1
    }
    
    # Check if there are changes to commit
    if git diff --quiet "$eso_app_file"; then
        log_message "No changes to commit (value already up to date)"
        return 0
    fi
    
    # Stage the file
    git add "$eso_app_file" || {
        log_error "Failed to stage external-secrets.yaml"
        return 1
    }
    
    # Commit with infrastructure context
    git commit -m "Update ESO IRSA role ARN from Terraform output

Injected by deployment automation after terraform apply.
Role ARN: $eso_role_arn" || {
        log_error "Failed to commit changes"
        return 1
    }
    
    # Push to remote
    git push || {
        log_error "Failed to push changes to remote repository"
        return 1
    }
    
    log_message "✓ ESO role ARN committed and pushed to Git"
}
