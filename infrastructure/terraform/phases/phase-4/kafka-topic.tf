# =============================================================================
# Phase 4 - Kafka Topic for Consolidation Events
# =============================================================================
# This file creates a Kafka topic in the existing MSK cluster (from Phase 3)
# for consolidation completion events that can be consumed by a Lambda function
# to update DynamoDB chargeback status.
# =============================================================================

# -----------------------------------------------------------------------------
# Kafka Topic Creation (using kafka_topic resource or null_resource)
# -----------------------------------------------------------------------------

# Note: Terraform doesn't have native support for MSK Serverless topics
# We'll use a null_resource with AWS CLI to create the topic
# This runs only when Kafka integration is enabled

resource "null_resource" "create_kafka_topic" {
  count = local.kafka_enabled ? 1 : 0

  triggers = {
    topic_name        = var.kafka_consolidation_topic
    partitions        = var.kafka_consolidation_topic_partitions
    replication       = var.kafka_consolidation_topic_replication
    bootstrap_servers = var.msk_bootstrap_brokers
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if topic exists
      TOPIC_EXISTS=$(aws kafka list-topics \
        --cluster-arn ${data.aws_msk_cluster.existing[0].arn} \
        --region ${local.region} \
        --query "Topics[?TopicName=='${var.kafka_consolidation_topic}'].TopicName" \
        --output text 2>/dev/null || echo "")

      if [ -z "$TOPIC_EXISTS" ]; then
        echo "Creating Kafka topic: ${var.kafka_consolidation_topic}"
        
        # Create topic configuration JSON
        cat > /tmp/kafka-topic-config-${var.kafka_consolidation_topic}.json <<EOF
{
  "Name": "${var.kafka_consolidation_topic}",
  "PartitionsCount": ${var.kafka_consolidation_topic_partitions},
  "ReplicationFactor": ${var.kafka_consolidation_topic_replication},
  "TopicConfiguration": {
    "Configs": [
      {
        "Key": "retention.ms",
        "Value": "604800000"
      },
      {
        "Key": "compression.type",
        "Value": "snappy"
      },
      {
        "Key": "max.message.bytes",
        "Value": "1048576"
      },
      {
        "Key": "cleanup.policy",
        "Value": "delete"
      }
    ]
  }
}
EOF
        
        # Create topic using AWS CLI (for MSK Serverless)
        aws kafka create-topic \
          --cluster-arn ${data.aws_msk_cluster.existing[0].arn} \
          --region ${local.region} \
          --cli-input-json file:///tmp/kafka-topic-config-${var.kafka_consolidation_topic}.json
        
        echo "Topic ${var.kafka_consolidation_topic} created successfully"
        rm -f /tmp/kafka-topic-config-${var.kafka_consolidation_topic}.json
      else
        echo "Topic ${var.kafka_consolidation_topic} already exists"
      fi
    EOT
  }

  depends_on = [data.aws_msk_cluster.existing]
}

# -----------------------------------------------------------------------------
# Data Source: Existing MSK Cluster (from Phase 3)
# -----------------------------------------------------------------------------

# We need to find the MSK cluster by name to get its ARN
data "aws_msk_cluster" "existing" {
  count = local.kafka_enabled ? 1 : 0

  cluster_name = "${local.name_prefix}-chargebacks-cluster"
}

# -----------------------------------------------------------------------------
# Security Group Rules for Glue to MSK Communication
# -----------------------------------------------------------------------------

# Allow Glue to connect to MSK on port 9098 (IAM auth)
resource "aws_security_group_rule" "glue_to_msk" {
  count = local.kafka_enabled && var.msk_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  description              = "Allow Glue ETL job to connect to MSK (IAM auth)"
  security_group_id        = var.msk_security_group_id
  source_security_group_id = aws_security_group.glue[0].id
}

# Security group for Glue connection
resource "aws_security_group" "glue" {
  count = local.kafka_enabled ? 1 : 0

  name_prefix = "${local.name_prefix}-glue-kafka-"
  description = "Security group for Glue ETL job to access MSK"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-glue-kafka-sg"
    }
  )
}

# Self-referencing rule for Glue
resource "aws_security_group_rule" "glue_self" {
  count = local.kafka_enabled ? 1 : 0

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

resource "aws_glue_connection" "msk" {
  count = local.kafka_enabled && length(var.private_subnet_ids) > 0 ? 1 : 0

  name = "${local.name_prefix}-msk-connection"

  connection_properties = {
    KAFKA_BOOTSTRAP_SERVERS = var.msk_bootstrap_brokers
    KAFKA_SSL_ENABLED       = "false" # IAM auth doesn't use SSL
  }

  physical_connection_requirements {
    availability_zone      = data.aws_subnet.private[0].availability_zone
    security_group_id_list = [aws_security_group.glue[0].id]
    subnet_id              = var.private_subnet_ids[0]
  }
}

# Data source for subnet AZ
data "aws_subnet" "private" {
  count = local.kafka_enabled && length(var.private_subnet_ids) > 0 ? 1 : 0
  id    = var.private_subnet_ids[0]
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
