variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "EKS cluster name for ALB controller management"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener"
  type        = string
}

variable "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID for target group attachment"
  type        = string
}

variable "enable_https" {
  description = "Toggle HTTPS listener creation"
  type        = bool
  default     = true
}

variable "quiz_app_host" {
  description = "Hostname that should route to the quiz application"
  type        = string
  default     = ""
}

variable "quiz_backend_path_patterns" {
  description = "Path patterns that should route to the quiz backend service"
  type        = list(string)
  default     = ["/api/*"]
}

variable "argocd_host" {
  description = "Hostname that should route to ArgoCD"
  type        = string
  default     = ""
}

variable "jenkins_host" {
  description = "Hostname that should route to Jenkins"
  type        = string
  default     = ""
}
