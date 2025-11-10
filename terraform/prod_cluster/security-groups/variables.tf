variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
}

variable "node_security_group_id" {
  description = "Security group ID of the EKS worker nodes"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "jenkins_security_group_id" {
  description = "Security group ID of the Jenkins instance (from main terraform)"
  type        = string
  default     = null
}

# Removed kubernetes_security_group_id - no longer needed for kubespray access

variable "kubernetes_api_port" {
  description = "Kubernetes API server port"
  type        = number
  default     = 443
}

variable "worker_node_port_range_start" {
  description = "Start of worker node port range"
  type        = number
  default     = 0
}

variable "worker_node_port_range_end" {
  description = "End of worker node port range"
  type        = number
  default     = 65535
}

variable "enable_security_group_rules" {
  description = "Enable security group rules (disable during destroy to prevent data source errors)"
  type        = bool
  default     = true
}