# ============================================================================
# Phase 2: Security Groups for Lambda
# ============================================================================
# Security Groups controlam o tráfego de rede (firewall) da Lambda

# ----------------------------------------------------------------------------
# Lambda Security Group
# ----------------------------------------------------------------------------

resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-lambda-${var.environment}-"
  description = "Security group for Lambda function to access VPC resources"
  vpc_id      = data.aws_vpc.phase1_vpc.id

  # ----------------------------------------------------------------------------
  # Egress Rules (Outbound Traffic)
  # ----------------------------------------------------------------------------
  
  # Allow HTTPS to DynamoDB via VPC Endpoint
  egress {
    description = "HTTPS to DynamoDB VPC Endpoint"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.phase1_vpc.cidr_block]
  }
  
  # Allow HTTPS to S3 via VPC Endpoint
  egress {
    description = "HTTPS to S3 VPC Endpoint"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.phase1_vpc.cidr_block]
  }
  
  # Allow DNS resolution (needed for VPC endpoints)
  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.phase1_vpc.cidr_block]
  }
  
  # Allow all outbound traffic (for external API calls, if needed)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ----------------------------------------------------------------------------
  # Ingress Rules (Inbound Traffic)
  # ----------------------------------------------------------------------------
  
  # Lambda normalmente não recebe tráfego inbound direto
  # API Gateway invoca a Lambda via AWS internal network
  # Se precisar de ingress no futuro, adicione aqui

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-lambda-sg-${var.environment}"
      Environment = var.environment
    }
  )
  
  # Lifecycle para evitar erros ao recriar security groups
  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# EXPLICAÇÃO DAS REGRAS:
# ============================================================================
#
# EGRESS (Saída):
# ----------------
# 1. HTTPS (443) para VPC - Acessa DynamoDB e S3 via VPC Endpoints
# 2. DNS (53) - Resolve nomes de VPC endpoints
# 3. All traffic (0.0.0.0/0) - Permite chamadas externas se necessário
#
# INGRESS (Entrada):
# ------------------
# - Nenhuma regra necessária
# - API Gateway invoca Lambda internamente (não passa pela VPC)
# - Lambda não recebe conexões inbound diretas
#
# ============================================================================
# SEGURANÇA:
# ============================================================================
# - Lambda fica em subnet PRIVADA (sem IP público)
# - Tráfego para DynamoDB/S3 fica dentro da VPC (via endpoints)
# - Tráfego externo (se necessário) sai via NAT Gateway
# - Sem ingress = Lambda não pode ser acessada diretamente de fora
# ============================================================================
