variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

# AWS Load Balancer Controller variables removed - now managed via script

variable "cluster_version" {
  description = "Kubernetes version of the EKS cluster (MAJOR.MINOR). Provided by parent module."
  type        = string
  # no default here so the parent module must pass a value
}