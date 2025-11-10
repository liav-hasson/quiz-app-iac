# =============================================================================
# FIBI Quiz App - Terraform Variables
# =============================================================================

# =============================================================================
# AWS Configuration
# =============================================================================
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-north-1"
}

# =============================================================================
# Project Configuration
# =============================================================================
variable "project_name" {
  description = "Name of the project (used for resource naming and tagging)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

# =============================================================================
# VPC Configuration
# =============================================================================
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# =============================================================================
# NAT Instance Configuration
# =============================================================================
variable "nat_ami_id" {
  description = "AMI ID for NAT instance"
  type        = string
}

variable "nat_instance_type" {
  description = "Instance type for NAT instance"
  type        = string
  default     = "t3.micro"
}

variable "nat_volume_size" {
  description = "Root volume size for NAT instance (GB)"
  type        = number
  default     = 8
}

# =============================================================================
# SSH Configuration (Optional - Only if needed for troubleshooting)
# =============================================================================
variable "ssh_key_pair_name" {
  description = "Name of the SSH key pair for EC2 instances (optional - SSM is primary access method)"
  type        = string
  default     = ""
}

# =============================================================================
# Jenkins Controller Configuration
# =============================================================================
variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins controller instance"
  type        = string
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins controller"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_volume_size" {
  description = "Root volume size for Jenkins controller (GB)"
  type        = number
  default     = 30
}

# =============================================================================
# EKS Cluster Configuration
# =============================================================================
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_node_groups" {
  description = "Map of EKS node group configurations"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
    labels         = map(string)
    tags           = map(string)
  }))
}

# =============================================================================
# Security Groups Configuration
# =============================================================================
variable "jenkins_security_group_name" {
  description = "Name for the Jenkins security group"
  type        = string
}

variable "kubernetes_security_group_name" {
  description = "Name for the Kubernetes security group"
  type        = string
}

# =============================================================================
# IRSA Service Account Configuration
# =============================================================================
variable "alb_service_account_name" {
  description = "Name of the service account for AWS Load Balancer Controller"
  type        = string
}

variable "alb_service_account_namespace" {
  description = "Namespace for AWS Load Balancer Controller service account"
  type        = string
}

variable "eso_service_account_name" {
  description = "Name of the service account for External Secrets Operator"
  type        = string
}

variable "eso_service_account_namespace" {
  description = "Namespace for External Secrets Operator service account"
  type        = string
}

# =============================================================================
# SSM Parameter Store Configuration
# =============================================================================
variable "ssm_parameter_prefix" {
  description = "Prefix for SSM Parameter Store paths"
  type        = string
  default     = "/fibi-quiz"
}

# =============================================================================
# Route53 DNS Configuration
# =============================================================================
variable "private_domain_name" {
  description = "Domain name for private hosted zone (internal VPC DNS)"
  type        = string
}

variable "public_zone_enabled" {
  description = "Enable public DNS records and ACM certificate creation"
  type        = bool
  default     = false
}

variable "public_zone_id" {
  description = "Route53 hosted zone ID for public domain"
  type        = string
  default     = ""
}

variable "public_domain" {
  description = "Public base domain name"
  type        = string
  default     = ""
}

variable "quiz_app_subdomain" {
  description = "Full subdomain for quiz application (e.g., quiz.example.com)"
  type        = string
  default     = ""
}

variable "argocd_subdomain" {
  description = "Full subdomain for ArgoCD (e.g., argocd.example.com)"
  type        = string
  default     = ""
}

variable "jenkins_subdomain" {
  description = "Full subdomain for Jenkins (e.g., jenkins.example.com)"
  type        = string
  default     = ""
}

# =============================================================================
# Tags
# =============================================================================
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}
