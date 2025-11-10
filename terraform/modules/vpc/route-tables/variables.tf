variable "vpc_id" {
  description = "VPC ID where route tables will be created"
  type        = string
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID for public routes"
  type        = string
}

variable "nat_gateway_id" {
  description = "NAT Gateway ID for private routes"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "weatherapp"
}