variable "nat_ami_id" {
  description = "AMI ID for NAT instance"
  type        = string
  # No default - passed from central config via VPC module
}

variable "instance_type" {
  description = "Instance type for NAT instance"
  type        = string
  # No default - passed from central config via VPC module
}

variable "volume_size" {
  description = "Root volume size for NAT instance"
  type        = number
  # No default - passed from central config via VPC module
}

variable "public_subnet_id" {
  description = "Public subnet ID for NAT instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "weatherapp"
}

# Bastion access removed - using SSM Session Manager for secure access
