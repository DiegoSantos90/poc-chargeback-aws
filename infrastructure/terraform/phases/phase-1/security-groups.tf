# ============================================================================
# Phase 1: Security Groups
# ============================================================================
# Security Groups controlam o tráfego de rede (firewall)

# ----------------------------------------------------------------------------
# Security Group for DynamoDB Access
# ----------------------------------------------------------------------------

resource "aws_security_group" "dynamodb_access" {
  name_prefix = "${var.project_name}-dynamodb-access-${var.environment}-"
  description = "Security group for resources that need DynamoDB access"
  vpc_id      = aws_vpc.main.id

  # Ingress: Allow HTTPS from within VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-dynamodb-sg-${var.environment}"
      Environment = var.environment
    }
  )
  
  # Lifecycle to handle name_prefix changes gracefully
  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# NOTA: Este security group será usado pela Lambda na Phase 2
# Permite que a Lambda acesse DynamoDB e S3 via VPC Endpoints
# ============================================================================
