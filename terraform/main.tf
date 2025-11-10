# =============================================================================
# FIBI Quiz App - Main Terraform Configuration
# =============================================================================

# VPC Module + NAT
module "vpc" {
  source = "./modules/vpc"

  vpc_name              = var.vpc_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  environment           = var.environment
  project_name          = var.project_name
  nat_ami_id            = var.nat_ami_id
  nat_instance_type     = var.nat_instance_type
  nat_volume_size       = var.nat_volume_size
  eks_cluster_name      = var.eks_cluster_name
}

# IAM Module
module "iam" {
  source               = "./modules/iam"
  environment          = var.environment
  project_name         = var.project_name
  eks_cluster_name     = var.eks_cluster_name
  eks_cluster_arn      = module.prod_cluster.cluster_arn
  oidc_provider_arn    = module.prod_cluster.oidc_provider_arn
  ssm_parameter_prefix = var.ssm_parameter_prefix
  
  # SA namespaces
  alb_service_account_name      = var.alb_service_account_name
  alb_service_account_namespace = var.alb_service_account_namespace
  eso_service_account_name      = var.eso_service_account_name
  eso_service_account_namespace = var.eso_service_account_namespace
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr
  environment = var.environment

  jenkins_security_group_name    = var.jenkins_security_group_name
  kubernetes_security_group_name = var.kubernetes_security_group_name
}

# Jenkins Instance
module "jenkins" {
  source = "./modules/ec2/jenkins"

  jenkins_ami_id            = var.jenkins_ami_id
  instance_type             = var.jenkins_instance_type
  volume_size               = var.jenkins_volume_size
  private_subnet_ids        = module.vpc.private_subnet_ids
  security_group_id         = module.security_groups.jenkins_security_group_id
  iam_instance_profile_name = module.iam.iam_instance_profile_name
  instance_name             = "${var.project_name}-jenkins"
}

# Route53 DNS & ACM Certificate
module "route53" {
  source = "./modules/route53"

  # Private DNS
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  private_domain_name = var.private_domain_name
  jenkins_private_ip  = module.jenkins.private_ip
  environment         = var.environment
  common_tags         = var.common_tags

  # Public DNS & ACM Certificate (certificate created independently)
  public_zone_enabled  = var.public_zone_enabled
  public_zone_id       = var.public_zone_id
  public_domain        = var.public_domain
  quiz_app_subdomain   = var.quiz_app_subdomain
  argocd_subdomain     = var.argocd_subdomain
  jenkins_subdomain    = var.jenkins_subdomain
}

# Production EKS Cluster  
module "prod_cluster" {
  source = "./prod_cluster"

  # Use existing VPC
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  public_subnets  = module.vpc.public_subnet_ids

  # Configuration from variables
  aws_region         = var.aws_region
  cluster_name       = var.eks_cluster_name
  kubernetes_version = var.kubernetes_version
  node_groups        = var.eks_node_groups
  # Certificate from route53 module - Route53 DNS records are now optional if ALB not ready
  certificate_arn    = module.route53.acm_certificate_arn

  # Cross-module security group references
  jenkins_security_group_id = module.security_groups.jenkins_security_group_id
  jenkins_instance_id       = module.jenkins.instance_id

  # Tags
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ClusterName = var.eks_cluster_name
    }
  )
}

# =============================================================================
# ALB DNS Records (created after cluster to break circular dependency)
# =============================================================================
data "aws_route53_zone" "public_for_alb" {
  count   = var.public_zone_enabled ? 1 : 0
  zone_id = var.public_zone_id
}

# Quiz app DNS record
resource "aws_route53_record" "quiz_app_alb" {
  count   = var.public_zone_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.public_for_alb[0].zone_id
  name    = var.quiz_app_subdomain
  type    = "A"

  alias {
    name                   = module.prod_cluster.alb_dns_name
    zone_id                = module.prod_cluster.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [module.prod_cluster]
}

# ArgoCD DNS record
resource "aws_route53_record" "argocd_alb" {
  count   = var.public_zone_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.public_for_alb[0].zone_id
  name    = var.argocd_subdomain
  type    = "A"

  alias {
    name                   = module.prod_cluster.alb_dns_name
    zone_id                = module.prod_cluster.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [module.prod_cluster]
}

# Jenkins DNS record
resource "aws_route53_record" "jenkins_alb" {
  count   = var.public_zone_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.public_for_alb[0].zone_id
  name    = var.jenkins_subdomain
  type    = "A"

  alias {
    name                   = module.prod_cluster.alb_dns_name
    zone_id                = module.prod_cluster.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [module.prod_cluster]
}
