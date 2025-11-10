variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_service_ipv4_cidr" {
  description = "CIDR block for Kubernetes service IP addresses"
  type        = string
  default     = "172.20.0.0/16"
}

variable "cluster_endpoint_public_access" {
  description = "Enable/disable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable/disable private API server endpoint"
  type        = bool
  default     = true
}