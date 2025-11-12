#!/bin/bash

# Jenkins Golden AMI Backup Script
# Creates a new AMI from the current Jenkins instance before infrastructure destroy
# Updates terraform.tfvars with the new AMI ID and removes old AMI
#
# Usage: ./backup-jenkins-ami.sh
# 
# This script should be run:
# - Before terraform destroy operations
# - When Jenkins contains important configuration updates

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root (workspace) is four levels up from lib/cleanup
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
LOG_FILE="/tmp/jenkins-ami-backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Exit code management for monitoring
write_exit_code() {
    echo "SCRIPT_EXIT_CODE=$1" >> "$LOG_FILE"
}

# Get Jenkins instance information
get_jenkins_instance() {
    step "Getting Jenkins instance information..."
    
    local region="${AWS_REGION:-eu-north-1}"
    local instance_name="quiz-app-jenkins"
    
    # Find the Jenkins instance
    JENKINS_INSTANCE_ID=$(aws ec2 describe-instances \
        --region "$region" \
        --filters "Name=tag:Name,Values=$instance_name" \
                  "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "None")
    
    if [[ "$JENKINS_INSTANCE_ID" == "None" || -z "$JENKINS_INSTANCE_ID" ]]; then
        error "Jenkins instance '$instance_name' not found or not running"
        return 1
    fi
    
    # Get instance details
    JENKINS_INSTANCE_INFO=$(aws ec2 describe-instances \
        --region "$region" \
        --instance-ids "$JENKINS_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0]' \
        --output json)
    
    JENKINS_INSTANCE_NAME=$(echo "$JENKINS_INSTANCE_INFO" | jq -r '.Tags[] | select(.Key=="Name") | .Value')
    JENKINS_AZ=$(echo "$JENKINS_INSTANCE_INFO" | jq -r '.Placement.AvailabilityZone')
    JENKINS_INSTANCE_TYPE=$(echo "$JENKINS_INSTANCE_INFO" | jq -r '.InstanceType')
    
    success "Found Jenkins instance: $JENKINS_INSTANCE_ID ($JENKINS_INSTANCE_NAME)"
    log "Instance details: $JENKINS_INSTANCE_TYPE in $JENKINS_AZ"
    
    return 0
}

# Get current AMI ID from terraform.tfvars
get_current_ami() {
    step "Getting current AMI ID from terraform.tfvars..."
    
    if [[ ! -f "$TFVARS_FILE" ]]; then
        warning "terraform.tfvars not found at $TFVARS_FILE"
        CURRENT_AMI_ID=""
        return 0
    fi
    
    CURRENT_AMI_ID=$(grep '^jenkins_ami_id' "$TFVARS_FILE" | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "")
    
    if [[ -z "$CURRENT_AMI_ID" ]]; then
        warning "No current AMI ID found in terraform.tfvars"
        CURRENT_AMI_ID=""
    else
        log "Current AMI ID: $CURRENT_AMI_ID"
    fi
}

# Create new AMI from Jenkins instance
create_jenkins_ami() {
    step "Creating new AMI from Jenkins instance..."

    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local ami_name="jenkins-golden-$timestamp"
    local ami_description="Jenkins Golden AMI backup created on $(date '+%Y-%m-%d %H:%M:%S')"
    local region="${AWS_REGION:-eu-north-1}"
    
    # Create the AMI (no-reboot to minimize disruption)
    NEW_AMI_ID=$(aws ec2 create-image \
        --region "$region" \
        --instance-id "$JENKINS_INSTANCE_ID" \
        --name "$ami_name" \
        --description "$ami_description" \
        --no-reboot \
        --query 'ImageId' \
        --output text)
    
    if [[ -z "$NEW_AMI_ID" ]]; then
        error "Failed to create AMI"
        return 1
    fi
    
    success "AMI creation initiated: $NEW_AMI_ID"
    
    # Tag the new AMI
    aws ec2 create-tags \
        --region "$region" \
        --resources "$NEW_AMI_ID" \
        --tags "Key=Name,Value=$ami_name" \
               "Key=Project,Value=quiz-app" \
               "Key=Type,Value=jenkins-golden-ami" \
               "Key=CreatedBy,Value=backup-script" \
               "Key=CreatedFrom,Value=$JENKINS_INSTANCE_ID" \
               "Key=Timestamp,Value=$timestamp"
    
    log "AMI tagged successfully"
    return 0
}

# Wait for AMI to be available
wait_for_ami_ready() {
    step "Waiting for AMI to be available..."
    
    local region="${AWS_REGION:-eu-north-1}"
    local max_wait_time=1800  # 30 minutes
    local check_interval=30   # 30 seconds
    local elapsed_time=0
    
    while [ $elapsed_time -lt $max_wait_time ]; do
        local ami_state=$(aws ec2 describe-images \
            --region "$region" \
            --image-ids "$NEW_AMI_ID" \
            --query 'Images[0].State' \
            --output text 2>/dev/null || echo "pending")
        
        # Handle different AMI states
        case "$ami_state" in
            "available")
                success "AMI $NEW_AMI_ID is now available"
                return 0
                ;;
            "failed")
                error "AMI creation failed"
                return 1
                ;;
            "pending")
                log "AMI creation in progress... ($elapsed_time/${max_wait_time}s)"
                ;;
            *)
                warning "Unknown AMI state: $ami_state"
                ;;
        esac
        
        sleep $check_interval
        elapsed_time=$((elapsed_time + check_interval))
    done
    
    error "AMI creation timed out after $max_wait_time seconds"
    return 1
}

# Update terraform.tfvars with new AMI ID
update_tfvars() {
    step "Updating terraform.tfvars with new AMI ID..."
    
    if [[ ! -f "$TFVARS_FILE" ]]; then
        error "terraform.tfvars not found at $TFVARS_FILE"
        return 1
    fi
    
    # Update the jenkins_ami_id line in terraform.tfvars
    sed -i 's/^jenkins_ami_id\s*=\s*"[^"]*"/jenkins_ami_id        = "'"$NEW_AMI_ID"'"/' "$TFVARS_FILE"
    
    # Verify the update
    local updated_ami=$(grep '^jenkins_ami_id' "$TFVARS_FILE" | sed 's/.*=\s*"\([^"]*\)".*/\1/')
    
    if [[ "$updated_ami" == "$NEW_AMI_ID" ]]; then
        success "terraform.tfvars updated with new AMI ID: $NEW_AMI_ID"
    else
        error "Failed to update terraform.tfvars"
        return 1
    fi
    
    return 0
}

# Remove old AMI
remove_old_ami() {
    step "Removing old AMI..."
    
    if [[ -z "$CURRENT_AMI_ID" ]]; then
        log "No old AMI to remove"
        return 0
    fi
    
    local region="${AWS_REGION:-eu-north-1}"
    
    # Check if old AMI exists
    local ami_exists=$(aws ec2 describe-images \
        --region "$region" \
        --image-ids "$CURRENT_AMI_ID" \
        --query 'Images[0].ImageId' \
        --output text 2>/dev/null || echo "None")
    
    if [[ "$ami_exists" == "None" ]]; then
        log "Old AMI $CURRENT_AMI_ID no longer exists"
        return 0
    fi
    
    # Get associated snapshots before deregistering
    local snapshots=$(aws ec2 describe-images \
        --region "$region" \
        --image-ids "$CURRENT_AMI_ID" \
        --query 'Images[0].BlockDeviceMappings[?Ebs.SnapshotId].Ebs.SnapshotId' \
        --output text)
    
    # Deregister the AMI
    if aws ec2 deregister-image --region "$region" --image-id "$CURRENT_AMI_ID"; then
        success "Deregistered old AMI: $CURRENT_AMI_ID"
        
        # Delete associated snapshots
        if [[ -n "$snapshots" ]]; then
            for snapshot in $snapshots; do
                if aws ec2 delete-snapshot --region "$region" --snapshot-id "$snapshot"; then
                    log "Deleted snapshot: $snapshot"
                else
                    warning "Failed to delete snapshot: $snapshot"
                fi
            done
        fi
    else
        warning "Failed to deregister old AMI: $CURRENT_AMI_ID"
        return 1
    fi
    
    return 0
}

# Show backup summary
show_summary() {
    step "Backup summary:"
    echo "════════════════════════════════════════════════════"
    echo "Jenkins Instance: $JENKINS_INSTANCE_ID ($JENKINS_INSTANCE_NAME)"
    echo "New AMI ID: $NEW_AMI_ID"
    if [[ -n "$CURRENT_AMI_ID" ]]; then
        echo "Old AMI ID: $CURRENT_AMI_ID (removed)"
    fi
    echo "Terraform Config: $TFVARS_FILE (updated)"
    echo "════════════════════════════════════════════════════"
}

# Main execution
main() {
    echo -e "${BLUE}🔄 Jenkins Golden AMI Backup${NC}"
    echo -e "═══════════════════════════════════"
    log "Starting Jenkins AMI backup process"
    
    # Execute backup steps
    if get_jenkins_instance && \
       get_current_ami && \
       create_jenkins_ami && \
       wait_for_ami_ready && \
       update_tfvars && \
       remove_old_ami; then
        
        show_summary
        success "Jenkins AMI backup completed successfully"
        write_exit_code 0
    else
        error "Jenkins AMI backup failed"
        write_exit_code 1
        exit 1
    fi
}

# Add error trap handler
trap 'write_exit_code $?; exit $?' ERR

# Run main function
main "$@"
