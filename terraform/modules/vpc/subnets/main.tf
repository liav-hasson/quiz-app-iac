# Public Subnets - Internet accessible
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = var.vpc_id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    {
      Name        = "${var.project_name}-public-subnet-${count.index + 1}-${var.environment}"
      Type        = "Public"
      AZ          = var.availability_zones[count.index]
      Environment = var.environment
      Project     = var.project_name
      # AWS Load Balancer Controller tags for ALB subnet discovery
      "kubernetes.io/role/elb" = "1"
      # Tag for EKS cluster
      "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    }
  )
}

# Private Subnets - No direct internet access
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name        = "${var.project_name}-private-subnet-${count.index + 1}-${var.environment}"
      Type        = "Private"
      AZ          = var.availability_zones[count.index]
      Environment = var.environment
      Project     = var.project_name
      # AWS Load Balancer Controller tags for internal ALB subnet discovery
      "kubernetes.io/role/internal-elb" = "1"
      # Tag for EKS cluster
      "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    }
  )
}