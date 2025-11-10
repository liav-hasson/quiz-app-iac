# =============================================================================
# PRIVATE HOSTED ZONE OUTPUTS
# =============================================================================
output "private_zone_id" {
  description = "ID of the private hosted zone"
  value       = aws_route53_zone.private.zone_id
}

output "private_zone_name" {
  description = "Name of the private hosted zone"
  value       = aws_route53_zone.private.name
}

output "jenkins_dns_name" {
  description = "DNS name for Jenkins service (internal)"
  value       = "jenkins.${var.private_domain_name}"
}

output "jenkins_url" {
  description = "Full Jenkins URL (internal)"
  value       = "http://jenkins.${var.private_domain_name}:8080"
}

# =============================================================================
# PUBLIC HOSTED ZONE OUTPUTS
# =============================================================================
output "public_zone_id" {
  description = "ID of the public hosted zone (if enabled)"
  value       = var.public_zone_enabled ? data.aws_route53_zone.public[0].zone_id : ""
}

output "public_zone_name" {
  description = "Name of the public hosted zone (if enabled)"
  value       = var.public_zone_enabled ? data.aws_route53_zone.public[0].name : ""
}

output "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate for HTTPS"
  # Reference the validation resource to ensure certificate is fully validated before use
  value       = var.public_zone_enabled ? aws_acm_certificate_validation.main[0].certificate_arn : ""
}

output "quiz_app_url" {
  description = "Public URL for quiz application"
  value       = var.public_zone_enabled ? "https://${var.quiz_app_subdomain}" : ""
}

output "argocd_url" {
  description = "Public URL for ArgoCD"
  value       = var.public_zone_enabled ? "https://${var.argocd_subdomain}" : ""
}