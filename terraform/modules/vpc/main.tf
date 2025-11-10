# ====================================
# VPC INFRASTRUCTURE (Modular Structure)
# ====================================

# VPC Core
module "vpc_core" {
  source = "./vpc-core"

  vpc_name     = var.vpc_name
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  project_name = var.project_name
}

# Internet Gateway
module "internet_gateway" {
  source = "./internet-gateway"

  vpc_id       = module.vpc_core.vpc_id
  environment  = var.environment
  project_name = var.project_name
}

# Subnets
module "subnets" {
  source = "./subnets"

  vpc_id               = module.vpc_core.vpc_id
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
  project_name         = var.project_name
  eks_cluster_name     = var.eks_cluster_name
}

# NAT Instance (Cost-optimized replacement for NAT Gateway)
module "nat_instance" {
  source = "./nat-instance"

  public_subnet_id      = module.subnets.public_subnet_ids[0] # First public subnet
  vpc_id                = module.vpc_core.vpc_id
  private_subnet_cidrs  = var.private_subnet_cidrs
  environment           = var.environment
  project_name          = var.project_name
  nat_ami_id            = var.nat_ami_id
  instance_type         = var.nat_instance_type
  volume_size           = var.nat_volume_size
}

# Route Tables
module "route_tables" {
  source = "./route-tables"

  vpc_id              = module.vpc_core.vpc_id
  internet_gateway_id = module.internet_gateway.internet_gateway_id
  nat_gateway_id      = module.nat_instance.nat_network_interface_id # Network interface ID for NAT instance
  public_subnet_ids   = module.subnets.public_subnet_ids
  private_subnet_ids  = module.subnets.private_subnet_ids
  environment         = var.environment
  project_name        = var.project_name
}
