# AWS Provider - inherited from parent
# No need to reconfigure, uses parent configuration

# Kubernetes authentication configuration (DRY principle)
locals {
  k8s_host                   = module.eks_cluster.cluster_endpoint
  k8s_cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  k8s_exec_api_version       = "client.authentication.k8s.io/v1beta1"
  k8s_exec_command           = "aws"
  k8s_exec_args              = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name, "--region", var.aws_region]
}

# Configure Kubernetes provider for THIS EKS cluster
provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = local.k8s_cluster_ca_certificate

  exec {
    api_version = local.k8s_exec_api_version
    command     = local.k8s_exec_command
    args        = local.k8s_exec_args
  }
}

# Configure Helm provider for THIS EKS cluster
provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = local.k8s_cluster_ca_certificate

    exec {
      api_version = local.k8s_exec_api_version
      command     = local.k8s_exec_command
      args        = local.k8s_exec_args
    }
  }
}