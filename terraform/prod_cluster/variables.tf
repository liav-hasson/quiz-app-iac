variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (MAJOR.MINOR). Provided by root module."
  type        = string
}


variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
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
  description = "Additional tags for all resources"
  type        = map(string)
}

variable "jenkins_security_group_id" {
  description = "Security group ID of the Jenkins instance (for EKS API access)"
  type        = string
  default     = null
}

variable "jenkins_instance_id" {
  description = "EC2 instance ID of the Jenkins server (for ALB target group attachment)"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener"
  type        = string
}

variable "enable_https" {
  description = "Whether to provision HTTPS listeners on the ALB"
  type        = bool
  default     = true
}

variable "quiz_app_host" {
  description = "Fully qualified hostname for the quiz application"
  type        = string
  default     = ""
}

variable "quiz_backend_path_patterns" {
  description = "Path patterns that should route to the quiz backend service"
  type        = list(string)
  default     = ["/api/*"]
}

variable "argocd_host" {
  description = "Fully qualified hostname for ArgoCD"
  type        = string
  default     = ""
}

variable "jenkins_host" {
  description = "Fully qualified hostname for Jenkins"
  type        = string
  default     = ""
}

variable "grafana_host" {
  description = "Fully qualified hostname for Grafana"
  type        = string
  default     = ""
}

variable "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver service account (IRSA)"
  type        = string
}