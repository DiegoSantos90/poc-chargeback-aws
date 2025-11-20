# =============================================================================
# Phase 4 - Kafka Topic for Consolidation Events
# =============================================================================
# This file creates Kafka topics in the existing MSK cluster (from Phase 3)
# for both the streaming pipeline and consolidation completion events.
# =============================================================================

# -----------------------------------------------------------------------------
# Kafka Topic Creation (using kafka_topic resource)
# -----------------------------------------------------------------------------

# Kafka topic for streaming chargeback events (from DynamoDB Streams via Lambda)
resource "kafka_topic" "chargebacks" {
  count = var.enable_kafka_notifications ? 1 : 0

  name               = "chargebacks"
  replication_factor = var.kafka_consolidation_topic_replication
  partitions         = var.kafka_consolidation_topic_partitions

  config = {
    "retention.ms"     = "604800000" # 7 days
    "compression.type" = "snappy"
    "cleanup.policy"   = "delete"
  }
}

# Kafka topic for consolidation completion events (from Glue ETL job)
resource "kafka_topic" "consolidation_events" {
  count = var.enable_kafka_notifications ? 1 : 0

  name               = var.kafka_consolidation_topic
  replication_factor = var.kafka_consolidation_topic_replication
  partitions         = var.kafka_consolidation_topic_partitions

  config = {
    "retention.ms"     = "604800000" # 7 days
    "compression.type" = "snappy"
    "cleanup.policy"   = "delete"
  }
}

# -----------------------------------------------------------------------------
# Security Group Rules for Glue to MSK Communication
# -----------------------------------------------------------------------------

# Allow Glue to connect to MSK on port 9098 (IAM auth)
resource "aws_security_group_rule" "glue_to_msk" {
  count = var.enable_kafka_notifications ? 1 : 0

  type                     = "ingress"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  description              = "Allow Glue ETL job to connect to MSK (IAM auth)"
  security_group_id        = var.msk_security_group_id
  source_security_group_id = aws_security_group.glue[0].id
}

# Security group for Glue connection
# Security group for Glue connection to MSK
resource "aws_security_group" "glue" {
  count = var.enable_kafka_notifications ? 1 : 0

  name        = "${local.name_prefix}-glue-to-msk"
  description = "Allow Glue ETL jobs to connect to MSK cluster"
  vpc_id      = var.vpc_id

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
      Name = "${local.name_prefix}-glue-to-msk"
    }
  )
}

# Self-referencing rule for Glue
resource "aws_security_group_rule" "glue_self" {
  count = var.enable_kafka_notifications ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  description              = "Allow Glue workers to communicate with each other"
  security_group_id        = aws_security_group.glue[0].id
  source_security_group_id = aws_security_group.glue[0].id
}

# -----------------------------------------------------------------------------
# Glue Connection for VPC Access (to reach MSK)
# -----------------------------------------------------------------------------

# Data source for subnet AZ (must be declared before use)
data "aws_subnet" "private" {
  count = var.enable_kafka_notifications && length(var.private_subnet_ids) > 0 ? 1 : 0
  id    = var.private_subnet_ids[0]
}

resource "aws_glue_connection" "msk" {
  count = var.enable_kafka_notifications && length(var.private_subnet_ids) > 0 ? 1 : 0

  name = "${local.name_prefix}-msk-connection"

  connection_properties = {
    KAFKA_BOOTSTRAP_SERVERS = var.msk_bootstrap_brokers
    KAFKA_SSL_ENABLED       = "true" # MSK IAM auth requires TLS on port 9098
  }

  physical_connection_requirements {
    availability_zone      = data.aws_subnet.private[0].availability_zone
    security_group_id_list = [aws_security_group.glue[0].id]
    subnet_id              = var.private_subnet_ids[0]
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "kafka_topic_name" {
  description = "Name of the Kafka topic for consolidation events"
  value       = local.kafka_enabled ? var.kafka_consolidation_topic : ""
}

output "kafka_enabled" {
  description = "Whether Kafka integration is enabled"
  value       = local.kafka_enabled
}

output "glue_security_group_id" {
  description = "Security group ID for Glue connection to MSK"
  value       = local.kafka_enabled ? aws_security_group.glue[0].id : ""
}

output "glue_connection_name" {
  description = "Name of the Glue connection for MSK access"
  value       = local.kafka_enabled && length(var.private_subnet_ids) > 0 ? aws_glue_connection.msk[0].name : ""
}
