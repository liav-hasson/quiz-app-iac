# EKS Cluster
module "eks_cluster" {
  source = "./eks-cluster"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.private_subnets
  tags            = var.tags
}

# Node Groups
module "node_groups" {
  source = "./node-groups"

  cluster_name         = module.eks_cluster.cluster_name
  cluster_version      = module.eks_cluster.cluster_version
  cluster_service_cidr = module.eks_cluster.cluster_service_cidr
  vpc_id               = var.vpc_id
  subnet_ids           = var.private_subnets
  node_groups          = var.node_groups
  tags                 = var.tags

  depends_on = [module.eks_cluster]
}

# EKS Addons
module "addons" {
  source = "./addons"

  cluster_name            = module.eks_cluster.cluster_name
  cluster_version         = var.kubernetes_version
  vpc_id                  = var.vpc_id
  ebs_csi_driver_role_arn = var.ebs_csi_driver_role_arn

  depends_on = [module.eks_cluster, module.node_groups]
}

# Security Groups Integration
module "security_groups" {
  source = "./security-groups"

  vpc_id                    = var.vpc_id
  cluster_security_group_id = module.eks_cluster.cluster_security_group_id
  node_security_group_id    = module.eks_cluster.node_security_group_id
  cluster_name              = module.eks_cluster.cluster_name
  jenkins_security_group_id = var.jenkins_security_group_id

  depends_on = [module.eks_cluster, module.node_groups]
}

# Application Load Balancer (for EKS services and Jenkins)
module "alb" {
  source = "./alb"

  project_name               = var.cluster_name
  cluster_name               = var.cluster_name
  vpc_id                     = var.vpc_id
  public_subnet_ids          = var.public_subnets
  certificate_arn            = var.certificate_arn
  jenkins_instance_id        = var.jenkins_instance_id
  common_tags                = var.tags
  enable_deletion_protection = false
  quiz_app_host              = var.quiz_app_host
  quiz_app_dev_host          = var.quiz_app_dev_host
  quiz_backend_path_patterns = var.quiz_backend_path_patterns
  argocd_host                = var.argocd_host
  jenkins_host               = var.jenkins_host
  grafana_host               = var.grafana_host
  loki_host                  = var.loki_host
  enable_https               = var.enable_https

  depends_on = [module.eks_cluster, module.node_groups]
}