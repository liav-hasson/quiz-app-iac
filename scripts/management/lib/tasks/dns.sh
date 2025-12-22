#!/bin/bash
# tasks/dns.sh
# DNS update operations for Route53

# Guard against double-loading
[[ -n "${_TASK_DNS_LOADED:-}" ]] && return 0
_TASK_DNS_LOADED=1

# =============================================================================
# Configuration
# =============================================================================

NLB_NAME="${NLB_NAME:-quiz-app-istio-gateway}"

# =============================================================================
# Wait for Istio NLB in AWS
# =============================================================================

task_wait_for_nlb() {
    local max_wait=300  # 5 minutes
    local waited=0
    local interval=10
    
    log_info "Waiting for NLB '$NLB_NAME' to be active in AWS..."
    
    while [[ $waited -lt $max_wait ]]; do
        # Query AWS directly for NLB status
        local nlb_info
        nlb_info=$(aws elbv2 describe-load-balancers \
            --region "$AWS_REGION" \
            --names "$NLB_NAME" \
            --query 'LoadBalancers[0].[DNSName,State.Code]' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$nlb_info" ]]; then
            local nlb_dns nlb_state
            nlb_dns=$(echo "$nlb_info" | awk '{print $1}')
            nlb_state=$(echo "$nlb_info" | awk '{print $2}')
            
            if [[ "$nlb_state" == "active" && -n "$nlb_dns" ]]; then
                log_success "NLB is active: $nlb_dns"
                NLB_DNS_RESULT="$nlb_dns"
                return 0
            fi
            
            log_info "NLB state: $nlb_state ($waited/$max_wait seconds)"
        else
            log_info "NLB not found yet... ($waited/$max_wait seconds)"
        fi
        
        sleep $interval
        waited=$((waited + interval))
    done
    
    log_error "Timeout waiting for NLB '$NLB_NAME'"
    log_error "Check: aws elbv2 describe-load-balancers --names $NLB_NAME"
    return 1
}

# =============================================================================
# Get NLB Hosted Zone ID
# =============================================================================

task_get_nlb_zone_id() {
    log_info "Getting NLB hosted zone ID..."
    
    local zone_id
    zone_id=$(aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --names "$NLB_NAME" \
        --query 'LoadBalancers[0].CanonicalHostedZoneId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$zone_id" && "$zone_id" != "None" ]]; then
        NLB_ZONE_ID_RESULT="$zone_id"
        return 0
    fi
    
    log_error "Could not get NLB hosted zone ID"
    return 1
}

# =============================================================================
# Update DNS Records
# =============================================================================

task_update_dns() {
    log_info "Updating DNS records to point to Istio NLB"
    echo ""
    
    # Wait for NLB to be ready
    if ! task_wait_for_nlb; then
        return 1
    fi
    local nlb_dns="$NLB_DNS_RESULT"
    
    # Get NLB hosted zone ID
    if ! task_get_nlb_zone_id; then
        return 1
    fi
    local nlb_zone_id="$NLB_ZONE_ID_RESULT"
    
    echo ""
    log_info "NLB Zone ID: $nlb_zone_id"
    
    # Get Route53 zone info from Terraform
    cd "$TERRAFORM_DIR" || return 1
    
    local hosted_zone_id domain
    hosted_zone_id=$(terraform output -raw public_zone_id 2>/dev/null || echo "")
    domain=$(terraform output -raw public_domain 2>/dev/null || echo "")
    
    if [[ -z "$hosted_zone_id" || -z "$domain" ]]; then
        log_error "Could not get Route53 outputs from Terraform"
        return 1
    fi
    
    log_info "Route53 Zone ID: $hosted_zone_id"
    log_info "Domain: $domain"
    
    # Update each subdomain
    for subdomain in "${DNS_SUBDOMAINS[@]}"; do
        local fqdn="${subdomain}.${domain}"
        
        log_info "Updating DNS: $fqdn -> $nlb_dns"
        
        aws route53 change-resource-record-sets \
            --hosted-zone-id "$hosted_zone_id" \
            --change-batch '{
                "Comment": "Update to Istio NLB",
                "Changes": [{
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": "'"$fqdn"'",
                        "Type": "A",
                        "AliasTarget": {
                            "HostedZoneId": "'"$nlb_zone_id"'",
                            "DNSName": "'"$nlb_dns"'",
                            "EvaluateTargetHealth": true
                        }
                    }
                }]
            }' >/dev/null 2>&1 || {
            log_warning "Failed to update DNS for $fqdn"
            continue
        }
        
        log_success "Updated: $fqdn"
    done
    
    log_success "DNS records updated"
    echo ""
    
    # Verify DNS records
    _verify_dns_records "$hosted_zone_id" "$domain" "$nlb_dns"
    
    return 0
}

# =============================================================================
# Verify DNS Records
# =============================================================================

_verify_dns_records() {
    local hosted_zone_id="$1"
    local domain="$2"
    local expected_nlb="$3"
    
    log_info "Verifying DNS records..."
    
    # Test first subdomain using Route53 API (authoritative, no cache)
    local test_fqdn="${DNS_SUBDOMAINS[0]}.${domain}"
    
    local dns_answer
    dns_answer=$(aws route53 test-dns-answer \
        --hosted-zone-id "$hosted_zone_id" \
        --record-name "$test_fqdn" \
        --record-type A \
        --query 'RecordData[0]' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$dns_answer" && "$dns_answer" != "None" ]]; then
        log_success "Route53 verified: $test_fqdn -> $dns_answer"
    else
        log_warning "Route53 test-dns-answer returned no result for $test_fqdn"
    fi
    
    # Info: Show nslookup result (may differ due to DNS propagation/cache)
    log_info "Public DNS lookup (may take time to propagate):"
    nslookup "$test_fqdn" 2>/dev/null | grep -A1 "Name:" | head -2 || echo "  (pending propagation)"
}
