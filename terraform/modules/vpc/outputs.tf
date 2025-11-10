# ====================================
# VPC CORE OUTPUTS
# ====================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc_core.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = var.vpc_cidr
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.internet_gateway.internet_gateway_id
}

# ====================================
# SUBNET OUTPUTS
# ====================================

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.subnets.private_subnet_ids
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = var.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = var.private_subnet_cidrs
}

output "availability_zones" {
  description = "Availability zones of the subnets"
  value       = var.availability_zones
}

# ====================================
# NAT INSTANCE OUTPUTS
# ====================================

output "nat_instance_id" {
  description = "ID of the NAT instance"
  value       = module.nat_instance.nat_instance_id
}

output "nat_network_interface_id" {
  description = "Primary network interface ID of the NAT instance"
  value       = module.nat_instance.nat_network_interface_id
}

output "nat_instance_private_ip" {
  description = "Private IP of the NAT instance"
  value       = module.nat_instance.nat_instance_private_ip
}

output "nat_elastic_ip" {
  description = "Elastic IP of the NAT instance"
  value       = module.nat_instance.nat_elastic_ip
}

output "nat_security_group_id" {
  description = "Security group ID of the NAT instance"
  value       = module.nat_instance.nat_security_group_id
}

# ====================================
# ROUTING OUTPUTS
# ====================================

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.route_tables.public_route_table_id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = module.route_tables.private_route_table_id
}