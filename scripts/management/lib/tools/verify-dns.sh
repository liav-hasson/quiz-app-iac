#!/bin/bash
# tools/verify-dns.sh
# Verify DNS configuration and ALB/NLB discovery

# Guard against double-loading
[[ -n "${_TOOL_VERIFY_DNS_LOADED:-}" ]] && return 0
_TOOL_VERIFY_DNS_LOADED=1

# =============================================================================
# DNS Verification
# =============================================================================

verify_dns_delegation() {
    log_info "Verifying NS delegation..."
    
    # Get zone info from Terraform
    cd "$TERRAFORM_DIR" || return 1
    
    local zone_id domain
    zone_id=$(terraform output -raw public_zone_id 2>/dev/null || echo "")
    domain=$(terraform output -raw public_domain 2>/dev/null || echo "")
    
    if [[ -z "$zone_id" || -z "$domain" ]]; then
        log_error "Could not get Route53 info from Terraform"
        return 1
    fi
    
    echo ""
    echo "Domain: $domain"
    echo "Zone ID: $zone_id"
    echo ""
    
    # Get authoritative NS records from Route53
    echo "Route53 Authoritative NS Records:"
    aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --query "ResourceRecordSets[?Type=='NS' && Name=='${domain}.'].ResourceRecords[*].Value" \
        --output text | tr '\t' '\n' | sed 's/^/  /'
    
    # Query public DNS
    echo ""
    echo "Public DNS NS Records (via 8.8.8.8):"
    if command -v dig &>/dev/null; then
        dig +short NS "$domain" @8.8.8.8 | sed 's/^/  /'
    else
        echo "  (dig not available)"
    fi
    
    echo ""
}

verify_dns_records() {
    log_info "Verifying DNS record resolution..."
    
    # Get domain from Terraform
    cd "$TERRAFORM_DIR" || return 1
    local domain
    domain=$(terraform output -raw public_domain 2>/dev/null || echo "")
    
    if [[ -z "$domain" ]]; then
        log_error "Could not get domain from Terraform"
        return 1
    fi
    
    echo ""
    echo "DNS Resolution Check:"
    echo ""
    
    for subdomain in "${DNS_SUBDOMAINS[@]}"; do
        local fqdn="${subdomain}.${domain}"
        local result
        
        if command -v dig &>/dev/null; then
            result=$(dig +short "$fqdn" @8.8.8.8 | head -1)
        else
            result=$(host "$fqdn" 2>/dev/null | grep "has address" | head -1 | awk '{print $NF}')
        fi
        
        if [[ -n "$result" ]]; then
            echo -e "  ${GREEN}[OK]${NC} $fqdn -> $result"
        else
            echo -e "  ${YELLOW}[--]${NC} $fqdn (not resolving)"
        fi
    done
    
    echo ""
}

discover_load_balancers() {
    log_info "Discovering Load Balancers..."
    
    echo ""
    echo "Application Load Balancers:"
    aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[?Type==`application`].[LoadBalancerName,DNSName,Scheme]' \
        --output text 2>/dev/null | while read -r name dns scheme; do
            [[ -z "$name" ]] && continue
            echo "  - $name"
            echo "    DNS: $dns"
            echo "    Scheme: $scheme"
            echo ""
        done
    
    echo "Network Load Balancers:"
    aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[?Type==`network`].[LoadBalancerName,DNSName,Scheme]' \
        --output text 2>/dev/null | while read -r name dns scheme; do
            [[ -z "$name" ]] && continue
            echo "  - $name"
            echo "    DNS: $dns"
            echo "    Scheme: $scheme"
            echo ""
        done
}

# =============================================================================
# Main Verification
# =============================================================================

run_dns_verification() {
    echo ""
    echo "================================"
    echo "    DNS Verification            "
    echo "================================"
    
    verify_dns_delegation
    verify_dns_records
    discover_load_balancers
    
    echo "DNS verification complete"
}
