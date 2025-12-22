#!/bin/bash
# tasks/jenkins-backup.sh
# Create AMI backup from Jenkins instance before destroy

# Guard against double-loading
[[ -n "${_TASK_JENKINS_BACKUP_LOADED:-}" ]] && return 0
_TASK_JENKINS_BACKUP_LOADED=1

# =============================================================================
# Configuration
# =============================================================================

JENKINS_INSTANCE_NAME="${JENKINS_INSTANCE_NAME:-devops-quiz-jenkins}"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"

# =============================================================================
# Main Backup Function
# =============================================================================

task_backup_jenkins_ami() {
    log_info "Starting Jenkins AMI backup"
    
    # Find Jenkins instance
    local instance_id
    instance_id=$(_get_jenkins_instance_id)
    
    if [[ -z "$instance_id" || "$instance_id" == "None" ]]; then
        log_warning "Jenkins instance not found or not running"
        return 0
    fi
    
    log_info "Found Jenkins instance: $instance_id"
    
    # Get current AMI from tfvars (if exists)
    local current_ami
    current_ami=$(_get_current_ami_from_tfvars)
    
    # Create new AMI
    local new_ami_id
    new_ami_id=$(_create_jenkins_ami "$instance_id")
    
    if [[ -z "$new_ami_id" ]]; then
        log_error "Failed to create Jenkins AMI"
        return 1
    fi
    
    log_success "Created new AMI: $new_ami_id"
    
    # Wait for AMI to be available
    if ! _wait_for_ami "$new_ami_id"; then
        log_warning "AMI may not be fully available yet"
    fi
    
    # Update terraform.tfvars
    if ! _update_tfvars_ami "$new_ami_id"; then
        log_warning "Failed to update terraform.tfvars"
        log_info "Manually set: jenkins_ami_id = \"$new_ami_id\""
    fi
    
    # Deregister old AMI (if different)
    if [[ -n "$current_ami" && "$current_ami" != "$new_ami_id" ]]; then
        _cleanup_old_ami "$current_ami"
    fi
    
    log_success "Jenkins AMI backup complete"
    return 0
}

# =============================================================================
# Helper Functions
# =============================================================================

_get_jenkins_instance_id() {
    aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=$JENKINS_INSTANCE_NAME" \
                  "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null
}

_get_current_ami_from_tfvars() {
    if [[ ! -f "$TFVARS_FILE" ]]; then
        return 0
    fi
    
    grep -E '^jenkins_ami_id[[:space:]]*=' "$TFVARS_FILE" 2>/dev/null | \
        sed 's/.*=[[:space:]]*"\(.*\)".*/\1/' | \
        tr -d ' '
}

_create_jenkins_ami() {
    local instance_id="$1"
    local timestamp
    timestamp=$(date +%Y-%m-%d-%H%M)
    local ami_name="jenkins-$timestamp"
    
    log_info "Creating AMI: $ami_name"
    
    aws ec2 create-image \
        --region "$AWS_REGION" \
        --instance-id "$instance_id" \
        --name "$ami_name" \
        --description "Jenkins golden AMI backup - $timestamp" \
        --no-reboot \
        --query 'ImageId' \
        --output text 2>/dev/null
}

_wait_for_ami() {
    local ami_id="$1"
    local max_wait=300
    local waited=0
    
    log_info "Waiting for AMI to be available..."
    
    while [[ $waited -lt $max_wait ]]; do
        local state
        state=$(aws ec2 describe-images \
            --region "$AWS_REGION" \
            --image-ids "$ami_id" \
            --query 'Images[0].State' \
            --output text 2>/dev/null)
        
        if [[ "$state" == "available" ]]; then
            log_success "AMI is available"
            return 0
        fi
        
        log_info "AMI state: $state ($waited/$max_wait seconds)"
        sleep 10
        waited=$((waited + 10))
    done
    
    log_warning "Timeout waiting for AMI"
    return 1
}

_update_tfvars_ami() {
    local new_ami_id="$1"
    
    if [[ ! -f "$TFVARS_FILE" ]]; then
        log_info "Creating terraform.tfvars with new AMI ID"
        echo "jenkins_ami_id = \"$new_ami_id\"" > "$TFVARS_FILE"
        return 0
    fi
    
    # Check if jenkins_ami_id already exists
    if grep -q '^jenkins_ami_id[[:space:]]*=' "$TFVARS_FILE" 2>/dev/null; then
        # Update existing line (using POSIX character class for portability)
        sed -i "s|^jenkins_ami_id[[:space:]]*=.*|jenkins_ami_id = \"$new_ami_id\"|" "$TFVARS_FILE"
    else
        # Append new line
        echo "" >> "$TFVARS_FILE"
        echo "jenkins_ami_id = \"$new_ami_id\"" >> "$TFVARS_FILE"
    fi
    
    log_info "Updated terraform.tfvars with new AMI: $new_ami_id"
    return 0
}

_cleanup_old_ami() {
    local old_ami_id="$1"
    
    log_info "Deregistering old AMI: $old_ami_id"
    
    # Get associated snapshots before deregistering
    local snapshots
    snapshots=$(aws ec2 describe-images \
        --region "$AWS_REGION" \
        --image-ids "$old_ami_id" \
        --query 'Images[0].BlockDeviceMappings[*].Ebs.SnapshotId' \
        --output text 2>/dev/null)
    
    # Deregister AMI
    aws ec2 deregister-image \
        --region "$AWS_REGION" \
        --image-id "$old_ami_id" 2>/dev/null || {
        log_warning "Failed to deregister old AMI"
        return 1
    }
    
    # Delete associated snapshots
    for snapshot in $snapshots; do
        [[ -z "$snapshot" || "$snapshot" == "None" ]] && continue
        log_info "Deleting snapshot: $snapshot"
        aws ec2 delete-snapshot \
            --region "$AWS_REGION" \
            --snapshot-id "$snapshot" 2>/dev/null || true
    done
    
    log_success "Old AMI cleaned up"
}
