# Public Route Table - Routes to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }

  tags = {
    Name        = "${var.project_name}-public-rt-${var.environment}"
    Type        = "Public"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_ids)
  subnet_id      = var.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public.id
}

# Private Route Table - Routes to NAT Instance
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  tags = {
    Name        = "${var.project_name}-private-rt-${var.environment}"
    Type        = "Private"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Route to NAT Instance (separate resource for better control)
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_gateway_id # Now contains network interface ID
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_ids)
  subnet_id      = var.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private.id
}