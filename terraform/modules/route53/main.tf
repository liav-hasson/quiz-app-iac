# =============================================================================
# PRIVATE HOSTED ZONE (Internal DNS for VPC)
# =============================================================================
# Creates private DNS zone for internal service discovery (Jenkins, EKS API, etc.)
resource "aws_route53_zone" "private" {
  name = var.private_domain_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name} Private DNS Zone"
      Environment = var.environment
      Service     = "DNS"
    }
  )
}

# Jenkins DNS Record (internal access)
resource "aws_route53_record" "jenkins" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "jenkins.${var.private_domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.jenkins_private_ip]
}

# EKS API Server DNS Record (optional - EKS provides its own DNS)
# Uncomment if you want a friendly internal name
# resource "aws_route53_record" "eks_api" {
#   zone_id = aws_route53_zone.private.zone_id
#   name    = "eks.${var.private_domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [var.eks_endpoint]
# }

# =============================================================================
# PUBLIC HOSTED ZONE (External DNS for public services)
# =============================================================================
# The public hosted zone is pre-existing in AWS Route53
# This module creates DNS records pointing to the ALB

# Data source to reference the existing public hosted zone
data "aws_route53_zone" "public" {
  count = var.public_zone_enabled ? 1 : 0
  
  zone_id = var.public_zone_id
}

# ACM Certificate for HTTPS
# Validates via DNS in the public hosted zone
resource "aws_acm_certificate" "main" {
  count = var.public_zone_enabled ? 1 : 0
  
  domain_name       = var.quiz_app_subdomain
  subject_alternative_names = [
    var.argocd_subdomain,
    var.jenkins_subdomain
  ]
  validation_method = "DNS"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name} HTTPS Certificate"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation record for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = var.public_zone_enabled ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.public[0].zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "main" {
  count = var.public_zone_enabled ? 1 : 0
  
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

