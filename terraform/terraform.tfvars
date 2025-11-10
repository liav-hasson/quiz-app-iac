# =============================================================================
# FIBI Quiz App - Terraform Configuration
# =============================================================================
# This file contains all centralized configuration values for the infrastructure
# Copy this to terraform.tfvars and customize for your environment

# =============================================================================
# AWS Configuration
# =============================================================================
aws_region = "eu-north-1"

# =============================================================================
# Project Configuration
# =============================================================================
project_name = "devops-quiz"
environment  = "production"

# =============================================================================
# VPC Configuration
# =============================================================================
vpc_name             = "devops-quiz-vpc"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["eu-north-1a", "eu-north-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

# =============================================================================
# NAT Instance Configuration (for cost savings vs NAT Gateway)
# =============================================================================
nat_ami_id        = "ami-087612fa932c8f075"  # NAT golden AMI
nat_instance_type = "t3.micro"
nat_volume_size   = 8

# =============================================================================
# Jenkins Controller Configuration
# =============================================================================
jenkins_ami_id        = "ami-0a83c166f673df4de"  # Jenkins golden AMI
jenkins_instance_type = "t3.small"
jenkins_volume_size   = 12

# =============================================================================
# EKS Cluster Configuration
# =============================================================================
eks_cluster_name   = "devops-quiz-eks"
kubernetes_version = "1.31"

# EKS Node Groups Configuration
eks_node_groups = {
  general = {
    desired_size   = 2
    min_size       = 1
    max_size       = 4
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    labels = {
      role = "general"
    }
    tags = {
      Name      = "devops-quiz-eks-node"
      NodeGroup = "general"
    }
  }
}

# =============================================================================
# Security Groups Configuration
# =============================================================================
jenkins_security_group_name    = "devops-jenkins-sg"
kubernetes_security_group_name = "devops-kubernetes-sg"

# =============================================================================
# IRSA Service Account Configuration
# =============================================================================
alb_service_account_name      = "aws-load-balancer-controller"
alb_service_account_namespace = "kube-system"
eso_service_account_name      = "external-secrets"
eso_service_account_namespace = "external-secrets-system"

# =============================================================================
# SSM Parameter Store Paths (for secrets management)
# =============================================================================
ssm_parameter_prefix = "/devops-quiz"

# =============================================================================
# Route53 DNS Configuration
# =============================================================================
# Private hosted zone (internal VPC DNS)
private_domain_name = "weatherlabs.internal"

# Public hosted zone (external DNS)
public_zone_enabled   = true
public_zone_id        = "Z06307832TD07PZVN77GO"  # weatherlabs.org hosted zone
public_domain         = "weatherlabs.org"
quiz_app_subdomain    = "quiz.weatherlabs.org"   # Quiz app public URL
argocd_subdomain      = "argocd.weatherlabs.org" # ArgoCD public URL
jenkins_subdomain     = "jenkins.weatherlabs.org" # Jenkins public URL

# =============================================================================
# Tags
# =============================================================================
common_tags = {
  Project     = "Devops-Quiz"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Owner       = "Liav"
}
