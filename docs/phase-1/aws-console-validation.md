# 🏗️ Step by Step: Phase 1 Infrastructure Validation in AWS Console

## 📊 Created Resources Summary

**Region**: `sa-east-1` (São Paulo)  
**VPC ID**: `vpc-06ec1227938c27384`  
**Total Resources**: 31 resources created

---

## 🔐 1. AWS CONSOLE ACCESS

### 1.1 Console Login
1. Access: https://console.aws.amazon.com/
2. Login with your credentials
3. **IMPORTANT**: Select region **"South America (São Paulo) sa-east-1"** in the top right corner

---

## 🌐 2. VPC (Virtual Private Cloud) VALIDATION

### 2.1 Verify Main VPC
1. Navigate to: **VPC > Your VPCs**
2. Search for VPC: `poc-chargeback-vpc`
3. ✅ **Verify**:
   - **VPC ID**: `vpc-06ec1227938c27384`
   - **CIDR**: `10.0.0.0/16`
   - **State**: `Available`
   - **DNS hostnames**: `Enabled`
   - **DNS resolution**: `Enabled`

### 2.2 Verificar Subnets
1. Navegue para: **VPC > Subnets**
2. Filtre por VPC: `vpc-06ec1227938c27384`
3. ✅ **Deve ter 4 subnets**:

#### Subnets Públicas:
- **poc-chargeback-public-subnet-1**
  - CIDR: `10.0.0.0/24`
  - AZ: `sa-east-1a`
  - Auto-assign public IPv4: `Yes`
  
- **poc-chargeback-public-subnet-2**
  - CIDR: `10.0.1.0/24`
  - AZ: `sa-east-1b`
  - Auto-assign public IPv4: `Yes`

#### Subnets Privadas:
- **poc-chargeback-private-subnet-1**
  - CIDR: `10.0.10.0/24`
  - AZ: `sa-east-1a`
  - Auto-assign public IPv4: `No`
  
- **poc-chargeback-private-subnet-2**
  - CIDR: `10.0.11.0/24`
  - AZ: `sa-east-1b`
  - Auto-assign public IPv4: `No`

### 2.3 Verificar Internet Gateway
1. Navegue para: **VPC > Internet Gateways**
2. ✅ **Verificar**:
   - **Name**: `poc-chargeback-igw`
   - **State**: `Attached`
   - **VPC**: `vpc-06ec1227938c27384`

### 2.4 Verificar NAT Gateways
1. Navegue para: **VPC > NAT Gateways**
2. ✅ **Deve ter 2 NAT Gateways**:
   - **poc-chargeback-nat-gateway-1**
     - State: `Available`
     - Subnet: `poc-chargeback-public-subnet-1`
     - Connectivity type: `Public`
   
   - **poc-chargeback-nat-gateway-2**
     - State: `Available`
     - Subnet: `poc-chargeback-public-subnet-2`
     - Connectivity type: `Public`

### 2.5 Verificar Route Tables
1. Navegue para: **VPC > Route Tables**
2. ✅ **Deve ter 3 route tables**:

#### Route Table Pública:
- **poc-chargeback-public-rt**
  - Routes:
    - `10.0.0.0/16` → `local`
    - `0.0.0.0/0` → `igw-04ed6f1389bd37a00`
  - Associated subnets: 2 public subnets

#### Route Tables Privadas (2):
- **poc-chargeback-private-rt-1**
  - Routes:
    - `10.0.0.0/16` → `local`
    - `0.0.0.0/0` → `nat-0d76e2ba8cfd4be14`

- **poc-chargeback-private-rt-2**
  - Routes:
    - `10.0.0.0/16` → `local`
    - `0.0.0.0/0` → `nat-07e2407ff54fc3c58`

### 2.6 Verificar VPC Endpoints
1. Navegue para: **VPC > Endpoints**
2. ✅ **Deve ter 2 endpoints**:
   - **poc-chargeback-s3-endpoint**
     - Service: `com.amazonaws.sa-east-1.s3`
     - Type: `Gateway`
     - State: `Available`
   
   - **poc-chargeback-dynamodb-endpoint**
     - Service: `com.amazonaws.sa-east-1.dynamodb`
     - Type: `Gateway`
     - State: `Available`

---

## 🗄️ 3. VALIDAÇÃO DO S3 (Simple Storage Service)

### 3.1 Verificar Buckets S3
1. Navegue para: **S3 > Buckets**
2. ✅ **Deve ter 2 buckets**:

#### Bucket Parquet:
- **Name**: `poc-chargeback-parquet-files-dev`
- **Region**: `sa-east-1`
- **Versioning**: `Enabled`
- **Tags**:
  - Environment: `dev`
  - Name: `Parquet Files Bucket`
  - Phase: `1`

#### Bucket CSV:
- **Name**: `poc-chargeback-csv-files-dev`
- **Region**: `sa-east-1`
- **Versioning**: `Enabled`
- **Tags**:
  - Environment: `dev`
  - Name: `CSV Files Bucket`
  - Phase: `1`

### 3.2 Testar Upload (Opcional)
1. Clique em um dos buckets
2. Clique em **Upload**
3. Adicione um arquivo de teste
4. Clique em **Upload**
5. ✅ **Verificar**: Upload realizado com sucesso

---

## 📊 4. VALIDAÇÃO DO DYNAMODB

### 4.1 Verificar Tabela DynamoDB
1. Navegue para: **DynamoDB > Tables**
2. ✅ **Verificar tabela**:
   - **Table name**: `chargebacks`
   - **Status**: `Active`
   - **Partition key**: `chargeback_id (S)`
   - **Billing mode**: `On-demand`

### 4.2 Verificar Global Secondary Index (GSI)
1. Clique na tabela `chargebacks`
2. Vá para aba **Indexes**
3. ✅ **Verificar GSI**:
   - **Index name**: `status-index`
   - **Partition key**: `status (S)`
   - **Status**: `Active`
   - **Projection type**: `ALL`

### 4.3 Verificar DynamoDB Streams
1. Na mesma página da tabela
2. Vá para aba **Exports and streams**
3. ✅ **Verificar DynamoDB stream**:
   - **Stream details**: `Enabled`
   - **View type**: `New and old images`
   - **Stream ARN**: `arn:aws:dynamodb:sa-east-1:730323515494:table/chargebacks/stream/2025-10-14T00:26:54.686`

### 4.4 Testar Insert (Opcional)
1. Vá para aba **Explore table items**
2. Clique em **Create item**
3. Adicione um item de teste:
   ```json
   {
     "chargeback_id": "test-123",
     "transaction_id": "txn-456",
     "amount": "100.00",
     "status": "PENDING"
   }
   ```
4. Clique em **Create item**
5. ✅ **Verificar**: Item criado com sucesso

---

## 🔒 5. VALIDAÇÃO DOS SECURITY GROUPS

### 5.1 Verificar Security Group
1. Navegue para: **EC2 > Security Groups**
2. Busque por: `poc-chargeback-dynamodb-access`
3. ✅ **Verificar configurações**:
   - **Group name**: `poc-chargeback-dynamodb-access*`
   - **VPC**: `vpc-06ec1227938c27384`
   - **Inbound rules**:
     - Type: `HTTPS`
     - Port: `443`
     - Source: `10.0.0.0/16`
   - **Outbound rules**:
     - Type: `All traffic`
     - Port: `All`
     - Destination: `0.0.0.0/0`

---

## 💰 6. VALIDAÇÃO DE CUSTOS

### 6.1 Verificar Billing Dashboard
1. Navegue para: **Billing > Bills**
2. ✅ **Recursos que geram custos**:
   - **NAT Gateways**: ~$45 USD/mês cada (2 = $90/mês)
   - **Elastic IPs**: Grátis enquanto anexados aos NAT Gateways
   - **DynamoDB**: Pay-per-request (mínimo para testes)
   - **S3**: Pay-per-use (mínimo para testes)
   - **VPC/Subnets**: Grátis

### 6.2 Configurar Billing Alert (Recomendado)
1. Navegue para: **CloudWatch > Billing**
2. Crie um alarme para custos > $50 USD
3. Configure notificação por email

---

## 🏷️ 7. VALIDAÇÃO DAS TAGS

### 7.1 Verificar Tags Padrão
Em todos os recursos, verifique as tags:
- ✅ **Environment**: `dev`
- ✅ **Phase**: `1`
- ✅ **Name**: Nome descritivo do recurso

### 7.2 Resource Groups (Opcional)
1. Navegue para: **Resource Groups & Tag Editor**
2. Crie um Resource Group para:
   - Tag: `Phase = 1`
3. ✅ **Deve mostrar todos os 31 recursos**

---

## 🔍 8. MONITORAMENTO E LOGS

### 8.1 CloudWatch Metrics
1. Navegue para: **CloudWatch > Metrics**
2. ✅ **Verificar métricas disponíveis**:
   - **VPC**: NetworkPacketsIn/Out
   - **DynamoDB**: ConsumedReadCapacityUnits
   - **S3**: BucketRequests
   - **NAT Gateway**: ActiveConnectionCount

### 8.2 VPC Flow Logs (Opcional)
1. Navegue para: **VPC > Your VPCs**
2. Selecione `poc-chargeback-vpc`
3. Actions > Create flow log
4. Configure para CloudWatch Logs

---

## ✅ 9. CHECKLIST FINAL DE VALIDAÇÃO

### Infraestrutura de Rede:
- [ ] VPC criada com CIDR 10.0.0.0/16
- [ ] 2 Subnets públicas em AZs diferentes
- [ ] 2 Subnets privadas em AZs diferentes  
- [ ] Internet Gateway attachado
- [ ] 2 NAT Gateways funcionando
- [ ] Route tables configuradas corretamente
- [ ] 2 VPC Endpoints (S3 e DynamoDB)

### Storage e Database:
- [ ] 2 Buckets S3 com versionamento
- [ ] Tabela DynamoDB ativa
- [ ] DynamoDB Streams habilitado
- [ ] GSI configurado

### Segurança:
- [ ] Security Group configurado
- [ ] Acesso HTTPS permitido na VPC
- [ ] Tags aplicadas corretamente

### Custos:
- [ ] Billing alert configurado
- [ ] NAT Gateways identificados como principais custos

---

## 🚨 10. TROUBLESHOOTING

### Problemas Comuns:

**Recursos não aparecem:**
- ✅ Verifique se está na região `sa-east-1`
- ✅ Verifique filtros aplicados no console

**Custos inesperados:**
- ✅ NAT Gateways são os principais custos (~$90/mês)
- ✅ Configure billing alerts imediatamente

**Acesso negado:**
- ✅ Verifique se está usando a conta correta
- ✅ Verifique permissões IAM

**Falha na validação:**
- ✅ Execute: `./scripts/validate-phase1.sh`
- ✅ Verifique logs do Terraform

---

## 🎯 PRÓXIMOS PASSOS

Após validar todos os itens:

1. ✅ **Infraestrutura validada e funcionando**
2. 🚀 **Pronto para implementar Fase 2**
3. 💡 **Considere implementar monitoramento adicional**
4. 📊 **Monitore custos regularmente**

**Documentação completa em**: `/scripts/README.md`  
**Destroy seguro**: `./scripts/destroy-phase1.sh`