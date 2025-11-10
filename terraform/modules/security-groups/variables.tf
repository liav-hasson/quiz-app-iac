variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "environment" {
  description = "Environment tag for security groups"
  type        = string
  default     = "shared"
}

# Security group names from central config
variable "jenkins_security_group_name" {
  description = "Name for the Jenkins security group"
  type        = string
  default     = "jenkins-sg"
}

variable "kubernetes_security_group_name" {
  description = "Name for the Kubernetes security group"
  type        = string
  default     = "kubernetes-sg"
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB (to allow traffic from ALB to Jenkins)"
  type        = string
  default     = null
}

# Jenkins ingress rules
variable "jenkins_ingress_rules" {
  description = "Jenkins ingress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Jenkins Web UI - Internal"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    },
    {
      description = "Jenkins Agent Communication"
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    },
    {
      description = "Jenkins Web UI - External NLB Access"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Kubernetes ingress rules
variable "kubernetes_ingress_rules" {
  description = "Kubernetes ingress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Kubernetes API Server"
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    },
    {
      description = "SSH from bastion"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Restricted to VPC, bastion resides in public subnet
    },
    {
      description = "etcd client communication"
      from_port   = 2379
      to_port     = 2380
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    },
    {
      description = "kubelet API"
      from_port   = 10250
      to_port     = 10250
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    },
    {
      description = "kube-scheduler"
      from_port   = 10259
      to_port     = 10259
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    },
    {
      description = "kube-controller-manager"
      from_port   = 10257
      to_port     = 10257
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    },
    {
      description = "NodePort Services"
      from_port   = 30000
      to_port     = 32767
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Will be overridden by var.vpc_cidr
    }
  ]
}
