# ============================================================================
# Phase 1: VPC and Network Infrastructure
# ============================================================================
# Este arquivo cria toda a infraestrutura de rede:
# - VPC
# - Internet Gateway
# - Public/Private Subnets
# - NAT Gateways
# - Route Tables

# ----------------------------------------------------------------------------
# VPC
# ----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-vpc-${var.environment}"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# Internet Gateway (for public subnet internet access)
# ----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-igw-${var.environment}"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# Public Subnets (for NAT Gateways)
# ----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-public-subnet-${count.index + 1}-${var.environment}"
      Environment = var.environment
      Type        = "public"
    }
  )
}

# ----------------------------------------------------------------------------
# Private Subnets (for Lambda and other private resources)
# ----------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-private-subnet-${count.index + 1}-${var.environment}"
      Environment = var.environment
      Type        = "private"
    }
  )
}

# ----------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# ----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-nat-eip-${count.index + 1}-${var.environment}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ----------------------------------------------------------------------------
# NAT Gateways (for private subnet internet access)
# ----------------------------------------------------------------------------

resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-nat-gateway-${count.index + 1}-${var.environment}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ----------------------------------------------------------------------------
# Route Table for Public Subnets
# ----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-public-rt-${var.environment}"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# Route Tables for Private Subnets (one per AZ)
# ----------------------------------------------------------------------------

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-private-rt-${count.index + 1}-${var.environment}"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# Route Table Associations
# ----------------------------------------------------------------------------

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Tables
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
