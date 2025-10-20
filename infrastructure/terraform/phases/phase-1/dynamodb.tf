# ============================================================================
# Phase 1: DynamoDB Table
# ============================================================================
# Tabela principal para armazenar dados de chargebacks

# ----------------------------------------------------------------------------
# Chargebacks Table
# ----------------------------------------------------------------------------

resource "aws_dynamodb_table" "chargebacks" {
  name         = "${var.project_name}-chargebacks-${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing - paga apenas pelo que usar
  hash_key     = "chargeback_id"   # Partition key (obrigatório)
  
  # Attributes - apenas os usados em keys ou indexes
  attribute {
    name = "chargeback_id"
    type = "S" # String
  }
  
  attribute {
    name = "status"
    type = "S" # String
  }
  
  # ----------------------------------------------------------------------------
  # DynamoDB Streams (para event-driven architecture no futuro)
  # ----------------------------------------------------------------------------
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  # Stream permite capturar mudanças na tabela para:
  # - Processar eventos assíncronos
  # - Sincronizar com outros sistemas
  # - Auditoria de mudanças
  
  # ----------------------------------------------------------------------------
  # Global Secondary Index (GSI) para queries por status
  # ----------------------------------------------------------------------------
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL" # Projeta todos os atributos
    
    # Não definimos read/write capacity porque billing_mode = PAY_PER_REQUEST
  }
  
  # GSI permite queries eficientes como:
  # - Buscar todos chargebacks com status="pending"
  # - Buscar todos chargebacks com status="approved"
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-chargebacks-table-${var.environment}"
      Environment = var.environment
    }
  )
}

# ============================================================================
# SCHEMA DA TABELA (exemplo):
# ============================================================================
# {
#   "chargeback_id": "cb_123456",           // Partition Key
#   "status": "pending",                    // GSI Hash Key
#   "merchant_id": "merch_789",
#   "amount": 150.00,
#   "currency": "USD",
#   "created_at": "2025-10-19T10:30:00Z",
#   "updated_at": "2025-10-19T10:30:00Z",
#   "reason": "Product not received",
#   "metadata": { ... }
# }
# ============================================================================
