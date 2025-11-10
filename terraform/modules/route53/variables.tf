# =============================================================================
# PRIVATE HOSTED ZONE VARIABLES
# =============================================================================
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the private hosted zone"
  type        = string
}

variable "private_domain_name" {
  description = "Domain name for the private hosted zone (e.g., devops-quiz.internal)"
  type        = string
}

variable "jenkins_private_ip" {
  description = "Private IP address of Jenkins instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# PUBLIC HOSTED ZONE VARIABLES
# =============================================================================
variable "public_zone_enabled" {
  description = "Enable public DNS record and ACM certificate creation"
  type        = bool
  default     = false
}

variable "public_zone_id" {
  description = "Route53 hosted zone ID for public domain"
  type        = string
  default     = ""
}

variable "public_domain" {
  description = "Public domain name (e.g., example.com)"
  type        = string
  default     = ""
}

variable "quiz_app_subdomain" {
  description = "Subdomain for quiz application (e.g., quiz.example.com)"
  type        = string
  default     = ""
}

variable "argocd_subdomain" {
  description = "Subdomain for ArgoCD (e.g., argocd.example.com)"
  type        = string
  default     = ""
}

variable "jenkins_subdomain" {
  description = "Subdomain for Jenkins (e.g., jenkins.example.com)"
  type        = string
  default     = ""
}

# Note: ALB DNS records moved to main.tf to break circular dependency