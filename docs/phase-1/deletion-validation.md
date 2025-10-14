# 🗑️ Deletion Validation - Phase 1

## 📋 Overview

This document details how to validate that **ALL** Phase 1 resources have been completely removed from AWS, ensuring there are no residual costs or orphaned resources.

---

## ⚡ QUICK VALIDATION (2 minutes)

### 1. Automatic Verification via Script
```bash
# Run the validation script again (should fail)
./scripts/validate-phase1.sh
```

**✅ Expected result**: Script should fail with message "Cannot get Terraform outputs"

### 2. Verification via Terraform
```bash
cd infrastructure/terraform
terraform show
```

**✅ Expected result**: "No state" or empty file

---

## 🔍 VALIDAÇÃO COMPLETA NO AWS CONSOLE

### 🌐 1. VERIFICAR VPC REMOVIDA

#### 1.1 Acessar VPC Console
1. Login no AWS Console
2. Região: **sa-east-1** (São Paulo)
3. Navegue para: **VPC > Your VPCs**

#### 1.2 Buscar VPC Específica
- **Buscar por**: `vpc-06ec1227938c27384`
- **Buscar por nome**: `poc-chargeback-vpc`

**✅ Resultado esperado**: 
- ❌ "No VPCs found"
- ❌ VPC não aparece na lista

#### 1.3 Verificar Componentes de Rede
**Subnets**:
```
VPC > Subnets > Buscar: poc-chargeback
```
**✅ Esperado**: Sem resultados

**Internet Gateways**:
```
VPC > Internet Gateways > Buscar: poc-chargeback-igw
```
**✅ Esperado**: Sem resultados

**NAT Gateways**:
```
VPC > NAT Gateways > Buscar: poc-chargeback
```
**✅ Esperado**: Sem resultados

**Route Tables**:
```
VPC > Route Tables > Buscar: poc-chargeback
```
**✅ Esperado**: Sem resultados

**VPC Endpoints**:
```
VPC > Endpoints > Buscar: poc-chargeback
```
**✅ Esperado**: Sem resultados

---

### 📊 2. VERIFICAR DYNAMODB REMOVIDO

#### 2.1 Acessar DynamoDB Console
1. Navegue para: **DynamoDB > Tables**
2. **Buscar por**: `chargebacks`

**✅ Resultado esperado**: 
- ❌ "No tables found"
- ❌ Tabela não aparece na lista

#### 2.2 Verificar Streams
```
DynamoDB > Exports and streams
```
**✅ Esperado**: Sem streams de chargebacks

---

### 🗄️ 3. VERIFICAR S3 BUCKETS REMOVIDOS

#### 3.1 Acessar S3 Console
1. Navegue para: **S3 > Buckets**

#### 3.2 Buscar Buckets Específicos
- **Buscar**: `poc-chargeback-parquet-files-dev`
- **Buscar**: `poc-chargeback-csv-files-dev`

**✅ Resultado esperado**:
- ❌ Buckets não aparecem na lista
- ❌ "No buckets found matching your search"

---

### 🔒 4. VERIFICAR SECURITY GROUPS

#### 4.1 Acessar EC2 Console
1. Navegue para: **EC2 > Security Groups**
2. **Buscar por**: `sg-07bca843ab83111ea`
3. **Buscar por nome**: `poc-chargeback-dynamodb`

**✅ Resultado esperado**:
- ❌ Security group não encontrado
- ❌ Sem resultados na busca

---

### 💰 5. VERIFICAR ELASTIC IPs LIBERADOS

#### 5.1 Acessar Elastic IPs
1. Navegue para: **EC2 > Elastic IPs**
2. **Buscar por**:
   - `eipalloc-0a99c953694182c36`
   - `eipalloc-0e8d51cce48d5ff9c`

**✅ Resultado esperado**:
- ❌ IPs não aparecem na lista (foram liberados)
- ✅ Ou aparecem como "Available" (não associados)

---

## 💸 6. VERIFICAÇÃO DE BILLING

### 6.1 Verificar Custos Parados
1. Navegue para: **Billing > Bills**
2. Vá para: **Cost Explorer**

#### 6.2 Recursos que DEVEM ter parado de cobrar:
- **NAT Gateways**: ~$45 USD/mês cada (principais custos)
- **Data Transfer**: Transferências via NAT
- **Elastic IPs**: Se estavam desassociados

#### 6.3 Configurar Alerta de Zero Custos
1. **CloudWatch > Billing**
2. Criar alarme para custos > $1 USD
3. ✅ Deve disparar apenas para custos mínimos (S3 residual, etc.)

---

## 🔍 7. VERIFICAÇÃO VIA AWS CLI

### 7.1 Comandos de Verificação

```bash
# Verificar VPC
aws ec2 describe-vpcs --vpc-ids vpc-06ec1227938c27384 --region sa-east-1
# Esperado: "InvalidVpcID.NotFound"

# Verificar DynamoDB
aws dynamodb describe-table --table-name chargebacks --region sa-east-1
# Esperado: "ResourceNotFoundException"

# Verificar S3 Buckets
aws s3 ls s3://poc-chargeback-parquet-files-dev --region sa-east-1
# Esperado: "NoSuchBucket"

aws s3 ls s3://poc-chargeback-csv-files-dev --region sa-east-1
# Esperado: "NoSuchBucket"

# Verificar NAT Gateways
aws ec2 describe-nat-gateways --nat-gateway-ids nat-0d76e2ba8cfd4be14 --region sa-east-1
# Esperado: "InvalidNatGatewayID.NotFound"

# Verificar Security Groups
aws ec2 describe-security-groups --group-ids sg-07bca843ab83111ea --region sa-east-1
# Esperado: "InvalidGroupId.NotFound"
```

---

## 📋 8. CHECKLIST DE VALIDAÇÃO COMPLETA

### Infraestrutura de Rede:
- [ ] ❌ VPC `vpc-06ec1227938c27384` não encontrada
- [ ] ❌ 4 Subnets removidas
- [ ] ❌ Internet Gateway removido
- [ ] ❌ 2 NAT Gateways removidos
- [ ] ❌ Route Tables removidas
- [ ] ❌ 2 VPC Endpoints removidos

### Storage e Database:
- [ ] ❌ DynamoDB table `chargebacks` não encontrada
- [ ] ❌ DynamoDB Streams removidos
- [ ] ❌ 2 Buckets S3 removidos

### Segurança e Rede:
- [ ] ❌ Security Group removido
- [ ] ❌ 2 Elastic IPs liberados

### Custos:
- [ ] ✅ NAT Gateway billing parado
- [ ] ✅ Elastic IP charges parados
- [ ] ✅ Billing alert configurado

### Estados do Sistema:
- [ ] ❌ Terraform state vazio
- [ ] ❌ Script de validação falha (esperado)

---

## 🚨 9. TROUBLESHOOTING

### Recursos Não Removidos

#### VPC não remove:
- **Causa**: Dependências ainda existem (ENIs, etc.)
- **Solução**: Aguardar 5-10 minutos, recursos se autodestroem

#### S3 Buckets não removem:
- **Causa**: Objetos ainda existem
- **Solução**: 
  ```bash
  aws s3 rm s3://bucket-name --recursive --region sa-east-1
  aws s3api delete-bucket --bucket bucket-name --region sa-east-1
  ```

#### NAT Gateway ainda cobrando:
- **Causa**: Demora para processar
- **Verificação**: Aguardar até 1 hora para billing parar

#### Elastic IP ainda cobrando:
- **Verificação**: Confirmar se foram realmente liberados
- **Solução**: Verificar se não estão "Available" (desassociados)

---

## ✅ 10. CONFIRMAÇÃO FINAL

### Método 1: Zero Resources
Execute este comando para contar recursos:
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Phase,Values=1" \
  --region sa-east-1 \
  --query 'length(ResourceTagMappingList)'
```
**✅ Resultado esperado**: `0`

### Método 2: Terraform State
```bash
cd infrastructure/terraform
terraform state list
```
**✅ Resultado esperado**: Sem output ou "No state"

### Método 3: Billing Dashboard
- **Custos NAT Gateway**: $0
- **Custos Elastic IP**: $0 
- **Custos gerais**: Apenas centavos (S3 residual)

---

## 🎯 11. PÓS-VALIDAÇÃO

### Se TUDO foi removido corretamente:
✅ **Parabéns! Limpeza 100% completa**
- Custos principais zerados
- Infraestrutura totalmente removida
- Pronto para próxima fase ou re-deploy

### Se encontrar recursos órfãos:
1. **Documente** quais recursos ainda existem
2. **Execute** remoção manual via console
3. **Verifique** dependências que impedem remoção
4. **Aguarde** até 1 hora para processamento billing

---

## 🔄 12. SCRIPT DE RE-VALIDAÇÃO

Depois da limpeza manual, re-execute:

```bash
# 1. Validação automática (deve falhar)
./scripts/validate-phase1.sh

# 2. Contagem de recursos (deve ser 0)
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Phase,Values=1" \
  --region sa-east-1 \
  --query 'length(ResourceTagMappingList)'

# 3. Billing check
aws ce get-cost-and-usage \
  --time-period Start=2025-10-13,End=2025-10-14 \
  --granularity DAILY \
  --metrics BlendedCost \
  --region sa-east-1
```

---

## 💡 DICAS IMPORTANTES

1. **Timing**: NAT Gateways levam tempo para processar billing
2. **Dependências**: VPC remove por último devido a dependências
3. **Billing**: Pode haver delay de até 1 hora para refletir
4. **Cleanup**: S3 com `force_destroy=true` remove automaticamente
5. **Validation**: Script automático é a forma mais rápida de validar

**Tempo total de validação**: 5-10 minutos + tempo de billing