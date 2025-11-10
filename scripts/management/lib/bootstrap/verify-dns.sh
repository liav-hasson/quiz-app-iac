#!/bin/bash

### DNS VERIFICATION AND ALB DISCOVERY SCRIPT ###
#
# Purpose: Verify DNS configuration and discover ALB DNS names created by Helm
# Usage: ./verify-dns.sh [--update-config]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root (workspace) is five levels up from lib/bootstrap
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../" && pwd)"
CENTRAL_CONFIG_FILE="$PROJECT_ROOT/configs/central-config.yaml"

# Configuration from central-config
PUBLIC_DOMAIN="$(yq e -r '.route53.public_hosted_zone.domain' "$CENTRAL_CONFIG_FILE")"
PUBLIC_ZONE_ID="$(yq e -r '.route53.public_hosted_zone.zone_id' "$CENTRAL_CONFIG_FILE")"
PUBLIC_ZONE_ENABLED="$(yq e -r '.route53.public_hosted_zone.enabled' "$CENTRAL_CONFIG_FILE")"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to verify NS delegation
verify_ns_delegation() {
    print_status "$BLUE" "\n=== Verifying NS Delegation for $PUBLIC_DOMAIN ==="
    
    # Get authoritative NS records from Route53
    local route53_ns
    route53_ns=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$PUBLIC_ZONE_ID" \
        --query "ResourceRecordSets[?Type=='NS' && Name=='${PUBLIC_DOMAIN}.'].ResourceRecords[*].Value" \
        --output text | tr '\t' '\n')
    
    print_status "$YELLOW" "Route53 Authoritative NS Records:"
    echo "$route53_ns"
    
    # Query public DNS for NS records
    local public_ns
    public_ns=$(dig +short NS "$PUBLIC_DOMAIN" @8.8.8.8 || echo "")
    
    print_status "$YELLOW" "\nPublic DNS NS Records (via 8.8.8.8):"
    if [ -z "$public_ns" ]; then
        print_status "$RED" "❌ No NS records found in public DNS"
        return 1
    else
        echo "$public_ns"
        
        # Check if any Route53 NS matches public NS
        local found=false
        while IFS= read -r r53_ns; do
            if echo "$public_ns" | grep -q "$r53_ns"; then
                found=true
                break
            fi
        done <<< "$route53_ns"
        
        if [ "$found" = true ]; then
            print_status "$GREEN" "✅ NS delegation is properly configured"
            return 0
        else
            print_status "$RED" "❌ NS delegation mismatch - domain may not be delegated to Route53"
            return 1
        fi
    fi
}

# Function to discover ALBs created by Helm AWS Load Balancer Controller
discover_albs() {
    print_status "$BLUE" "\n=== Discovering ALBs Created by Helm ==="
    
    # List all ALBs
    local albs
    albs=$(aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[?Type==`application`].[LoadBalancerName,DNSName,CanonicalHostedZoneId,Scheme]' \
        --output text)
    
    if [ -z "$albs" ]; then
        print_status "$YELLOW" "⚠️  No ALBs found - Helm may not have created them yet"
        print_status "$YELLOW" "    Run this script after deploying Helm charts (bootstrap-dev, bootstrap-prod)"
        return 1
    fi
    
    print_status "$GREEN" "Found ALBs:"
    echo "$albs" | while read -r name dns_name zone_id scheme; do
        echo "  - $name"
        echo "    DNS: $dns_name"
        echo "    Zone ID: $zone_id"
        echo "    Scheme: $scheme"
        echo ""
    done
    
    # Try to identify dev and prod ALBs by tags
    print_status "$BLUE" "Attempting to identify dev/prod ALBs by tags..."
    
    local dev_alb_arn dev_alb_dns dev_alb_zone
    local prod_alb_arn prod_alb_dns prod_alb_zone
    
    # Get all ALB ARNs
    local alb_arns
    alb_arns=$(aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' \
        --output text)
    
    # Check tags for each ALB
    for arn in $alb_arns; do
        local tags
        tags=$(aws elbv2 describe-tags --resource-arns "$arn" \
            --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster'].Value" \
            --output text || echo "")
        
        if echo "$tags" | grep -q "dev-cluster"; then
            dev_alb_arn="$arn"
            dev_alb_dns=$(aws elbv2 describe-load-balancers --load-balancer-arns "$arn" \
                --query 'LoadBalancers[0].DNSName' --output text)
            dev_alb_zone=$(aws elbv2 describe-load-balancers --load-balancers "$arn" \
                --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)
        elif echo "$tags" | grep -q "weatherapp-prod-eks"; then
            prod_alb_arn="$arn"
            prod_alb_dns=$(aws elbv2 describe-load-balancers --load-balancer-arns "$arn" \
                --query 'LoadBalancers[0].DNSName' --output text)
            prod_alb_zone=$(aws elbv2 describe-load-balancers --load-balancer-arns "$arn" \
                --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)
        fi
    done
    
    if [ -n "$dev_alb_dns" ]; then
        print_status "$GREEN" "✅ Dev ALB identified:"
        print_status "$YELLOW" "   DNS: $dev_alb_dns"
        print_status "$YELLOW" "   Zone ID: $dev_alb_zone"
    else
        print_status "$YELLOW" "⚠️  Dev ALB not found"
    fi
    
    if [ -n "$prod_alb_dns" ]; then
        print_status "$GREEN" "✅ Prod ALB identified:"
        print_status "$YELLOW" "   DNS: $prod_alb_dns"
        print_status "$YELLOW" "   Zone ID: $prod_alb_zone"
    else
        print_status "$YELLOW" "⚠️  Prod ALB not found"
    fi
    
    # Export for use in update function
    export DEV_ALB_DNS="$dev_alb_dns"
    export DEV_ALB_ZONE="$dev_alb_zone"
    export PROD_ALB_DNS="$prod_alb_dns"
    export PROD_ALB_ZONE="$prod_alb_zone"
}

# Function to verify ALIAS record resolution
verify_alias_records() {
    print_status "$BLUE" "\n=== Verifying ALIAS Record Resolution ==="
    
    local subdomains=("dev" "argocd" "gitlab" "jenkins" "")
    
    for subdomain in "${subdomains[@]}"; do
        if [ -z "$subdomain" ]; then
            local fqdn="$PUBLIC_DOMAIN"
        else
            local fqdn="${subdomain}.${PUBLIC_DOMAIN}"
        fi
        
        echo -n "Checking $fqdn... "
        
        # Query DNS
        local result
        result=$(dig +short "$fqdn" @8.8.8.8 || echo "")
        
        if [ -n "$result" ]; then
            print_status "$GREEN" "✅ Resolves to: $result"
        else
            print_status "$RED" "❌ No resolution"
        fi
    done
}

# Function to update central-config with discovered ALB values
update_central_config() {
    print_status "$BLUE" "\n=== Updating central-config.yaml with ALB DNS names ==="
    
    if [ -z "$DEV_ALB_DNS" ] && [ -z "$PROD_ALB_DNS" ]; then
        print_status "$RED" "❌ No ALBs discovered - cannot update config"
        return 1
    fi
    
    # Backup central-config
    cp "$CENTRAL_CONFIG_FILE" "${CENTRAL_CONFIG_FILE}.backup-$(date +%Y%m%d_%H%M%S)"
    
    # Update dev ALB if found
    if [ -n "$DEV_ALB_DNS" ]; then
        yq e -i ".route53.public_hosted_zone.dev_alb_dns_name = \"$DEV_ALB_DNS\"" "$CENTRAL_CONFIG_FILE"
        yq e -i ".route53.public_hosted_zone.dev_alb_zone_id = \"$DEV_ALB_ZONE\"" "$CENTRAL_CONFIG_FILE"
        print_status "$GREEN" "✅ Updated dev ALB configuration"
    fi
    
    # Update prod ALB if found
    if [ -n "$PROD_ALB_DNS" ]; then
        yq e -i ".route53.public_hosted_zone.prod_alb_dns_name = \"$PROD_ALB_DNS\"" "$CENTRAL_CONFIG_FILE"
        yq e -i ".route53.public_hosted_zone.prod_alb_zone_id = \"$PROD_ALB_ZONE\"" "$CENTRAL_CONFIG_FILE"
        print_status "$GREEN" "✅ Updated prod ALB configuration"
    fi
    
    print_status "$YELLOW" "\n📝 Next steps:"
    print_status "$YELLOW" "1. Review the changes in $CENTRAL_CONFIG_FILE"
    print_status "$YELLOW" "2. Run 'cd terraform && terraform apply' to create DNS ALIAS records"
    print_status "$YELLOW" "3. Wait a few minutes for DNS propagation"
    print_status "$YELLOW" "4. Re-run this script to verify ALIAS record resolution"
}

# Main execution
main() {
    if [ "$PUBLIC_ZONE_ENABLED" != "true" ]; then
        print_status "$YELLOW" "⚠️  Public hosted zone is disabled in central-config.yaml"
        print_status "$YELLOW" "    Set route53.public_hosted_zone.enabled to true to enable public DNS"
        exit 0
    fi
    
    print_status "$BLUE" "=== DNS Verification for $PUBLIC_DOMAIN ==="
    print_status "$BLUE" "Zone ID: $PUBLIC_ZONE_ID"
    
    # Verify NS delegation
    verify_ns_delegation
    
    # Discover ALBs
    discover_albs
    
    # Verify ALIAS records if they exist
    verify_alias_records
    
    # Update config if requested
    if [ "${1:-}" = "--update-config" ]; then
        update_central_config
    else
        print_status "$YELLOW" "\n💡 Tip: Run with --update-config to automatically update central-config.yaml"
    fi
    
    print_status "$GREEN" "\n✅ DNS verification complete"
}

main "$@"
