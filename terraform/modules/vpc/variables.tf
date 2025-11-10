# VPC Configuration
variable "vpc_name" {
  description = "Name for the VPC (pre-constructed from central config)"
  type        = string
  # No default - passed from central config
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# Subnet Configuration
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# Environment and Naming
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  # No default - passed from root module
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  # No default - passed from root module
}

# Bastion access removed - using SSM only for EC2 access

# NAT instance configuration
variable "nat_ami_id" {
  description = "AMI ID used for the NAT instance"
  type        = string
}

variable "nat_instance_type" {
  description = "Instance type for the NAT instance"
  type        = string
}

variable "nat_volume_size" {
  description = "Root volume size (GiB) for the NAT instance"
  type        = number
}

variable "eks_cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
}

# (removed duplicate NAT variables)
