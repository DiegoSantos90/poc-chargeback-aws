# =============================================================================
# Phase 3 - Amazon MSK Serverless Configuration
# =============================================================================
# This file creates MSK Serverless cluster for Kafka streaming.
# MSK Serverless auto-scales capacity and eliminates broker management.
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group for MSK Cluster
# -----------------------------------------------------------------------------

resource "aws_security_group" "msk" {
  name        = local.msk_security_group_name
  description = "Security group for MSK Serverless cluster"
  vpc_id      = var.vpc_id

  # Allow inbound from Flink (self-reference)
  ingress {
    description = "Kafka plaintext from Flink"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Kafka IAM authentication from Flink"
    from_port   = 9098
    to_port     = 9098
    protocol    = "tcp"
    self        = true
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.msk_security_group_name
    }
  )
}

# Security Group Rules to allow Lambda access to MSK
# (created separately to avoid circular dependency)
resource "aws_security_group_rule" "msk_from_lambda_9092" {
  type                     = "ingress"
  description              = "Kafka plaintext from Lambda"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_stream_processor.id
  security_group_id        = aws_security_group.msk.id
}

resource "aws_security_group_rule" "msk_from_lambda_9098" {
  type                     = "ingress"
  description              = "Kafka IAM authentication from Lambda"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_stream_processor.id
  security_group_id        = aws_security_group.msk.id
}

# -----------------------------------------------------------------------------
# MSK Serverless Cluster Configuration
# -----------------------------------------------------------------------------

resource "aws_msk_serverless_cluster" "main" {
  cluster_name = local.msk_cluster_name

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.msk.id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.msk_cluster_name
    }
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for MSK (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${local.msk_cluster_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "/aws/msk/${local.msk_cluster_name}"
    }
  )
}

# -----------------------------------------------------------------------------
# Note: Kafka Topic Creation
# -----------------------------------------------------------------------------
# MSK Serverless doesn't support automatic topic creation via Terraform.
# Topics must be created manually using Kafka command-line tools or via Lambda.
# 
# To create the topic after deployment:
# 
# 1. Get bootstrap servers:
#    terraform output -raw msk_bootstrap_brokers
# 
# 2. Use AWS CLI to create topic:
#    aws kafka create-configuration \
#      --name chargebacks-topic-config \
#      --kafka-versions "2.8.1" \
#      --server-properties file://topic-config.properties
# 
# 3. Or use kafka-topics.sh from a client EC2/Lambda:
#    kafka-topics.sh --bootstrap-server <BOOTSTRAP_SERVERS> \
#      --command-config client.properties \
#      --create \
#      --topic chargebacks \
#      --partitions 3 \
#      --replication-factor 3
# 
# client.properties should contain:
#   security.protocol=SASL_SSL
#   sasl.mechanism=AWS_MSK_IAM
#   sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
#   sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
# =============================================================================
