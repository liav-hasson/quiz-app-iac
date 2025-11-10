variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "cluster_service_cidr" {
  description = "Service CIDR block for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the node groups will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the node groups"
  type        = list(string)
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    min_size       = number
    max_size       = number
    desired_size   = number
    instance_types = list(string)
    capacity_type  = string
  }))
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}