# RDS Multi-Region Replication & Failover Architecture

## 1. RDS Đồng Bộ Như Thế Nào (Synchronization Mechanism)

### 1.1 Kiến Trúc Replication Hiện Tại

```
┌─────────────────────────────────┐        ┌──────────────────────────────┐
│     PRIMARY REGION              │        │   SECONDARY REGION           │
│  (ap-southeast-1)               │        │  (ap-northeast-1)            │
│                                 │        │                              │
│  ┌──────────────────────────┐   │        │  ┌────────────────────────┐  │
│  │ RDS Primary Instance     │   │◄──────────│ RDS Read Replica       │  │
│  │ (Writable)               │   │ Async   │ (Read-Only)             │  │
│  │ - ha-db (MySQL 8.0)      │   │ Stream  │ - ha-db-secondary       │  │
│  │ - Multi-AZ enabled       │   │        │ - Same VPC (Secondary)  │  │
│  │ - Encryption enabled     │   │        │ - Encryption enabled    │  │
│  └──────────────────────────┘   │        │ └────────────────────────┘  │
│         │                        │        │          │                  │
│         ▼                        │        │          ▼                  │
│  Binary Log Stream (Async)       │        │  Apply Logs (Async)         │
│  Retention: 3-7 days             │        │                             │
│                                 │        │                             │
└─────────────────────────────────┘        └──────────────────────────────┘
         │
         ▼
    ┌──────────────────────────┐
    │  RDS Backups (AWS)       │
    │  - Automated snapshots   │
    │  - Retention: 3 days     │
    └──────────────────────────┘
```

### 1.2 Cơ Chế Đồng Bộ Dữ Liệu

**Kiểu Replication: Asynchronous**

1. **Primary DB (Region chính):**
   - Nhận tất cả các ghi dữ liệu (INSERT, UPDATE, DELETE)
   - Ghi dữ liệu vào storage local
   - Ghi Binary Logs của tất cả thay đổi
   - Trả kết quả cho application ngay lập tức (không chờ replica)

2. **Replication Stream:**
   - AWS RDS tự động stream Binary Logs từ Primary → Secondary
   - Đảm bảo tính toàn vẹn dữ liệu (consistent)
   - Có lag từ vài mili-giây đến vài giây (tuỳ khối lượng ghi)

3. **Secondary DB (Read Replica):**
   - Nhận Binary Logs từ Primary
   - Apply các thay đổi vào local storage
   - Luôn ở trạng thái **Read-Only** (không thể ghi trực tiếp)
   - Có thể có lag từ Primary (trong phần lớn trường hợp < 1 giây)

### 1.3 Terraform Configuration Hiện Tại

```hcl
# Primary Database (Region chính)
module "primary_database" {
  source = "./modules/database"
  
  identifier  = var.db_identifier          # "ha-db"
  vpc_id      = module.primary_vpc.vpc_id
  subnet_ids  = module.primary_vpc.private_subnet_ids
  # replicate_source_db = null (Primary)
}

# Secondary Database (Read Replica - Region phụ)
module "secondary_database" {
  count = var.enable_secondary_cluster ? 1 : 0
  
  providers = {
    aws = aws.secondary
  }
  
  source = "./modules/database"
  
  identifier          = "${var.db_identifier}-secondary"
  vpc_id              = module.secondary_vpc[0].vpc_id
  subnet_ids          = module.secondary_vpc[0].private_subnet_ids
  replicate_source_db = module.primary_database.db_instance_arn  # Trỏ tới Primary
}
```

**Đặc điểm:**
- Primary: Writable, Multi-AZ (có failover tự động trong AZ)
- Secondary: Read-only, không Multi-AZ mặc định
- Synchronization tự động được AWS RDS quản lý

---

## 2. Failover Flow (Quy Trình Failover)

### 2.1 Kiến Trúc Failover Hiện Tại

```
                    ┌─────────────────────────┐
                    │   Route53 DNS           │
                    │  (Failover Policy)      │
                    └────────────┬────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
            ┌──────────────────┐    ┌──────────────────┐
            │  PRIMARY ALB     │    │  SECONDARY ALB   │
            │  (Active)        │    │  (Standby)       │
            │  ap-southeast-1  │    │  ap-northeast-1  │
            └────────┬─────────┘    └──────┬───────────┘
                     │                      │
            ┌────────┴──────────┐           │
            │  Health Check     │           │
            │  (HTTP/HTTPS)     │           │
            │  Check every 30s  │           │
            └────────┬──────────┘           │
                     │                      │
        ┌────────────┴────────────┐         │
        │                         │         │
        ▼                         ▼         │
    ┌─────────────────┐   ┌─────────────┐  │
    │ PRIMARY OK?     │   │ On failure: │  │
    │ (Healthy)       │   │ Route53     │  │
    │                 │   │ switches to │  │
    │ YES → Use       │   │ SECONDARY   │  │
    │ PRIMARY ALB     │   │ record      │  │
    └─────────────────┘   └─────────────┘  │
                                           ▼
                              ┌──────────────────┐
                              │ Use SECONDARY    │
                              │ ALB endpoint     │
                              │ (failover link)  │
                              └──────────────────┘
```

### 2.2 Các Tầng Failover

#### **Tầng 1: Application Layer (ALB Failover)**
- **Trigger:** Route53 Health Check thất bại
- **Cách hoạt động:** 
  - Route53 liên tục gửi HTTP requests tới Primary ALB
  - Nếu Primary ALB không phản hồi hoặc trả lỗi, health check failed
  - Route53 tự động chuyển traffic sang Secondary ALB
- **Thời gian failover:** ~30 giây (tuỳ cấu hình health check interval)
- **DNS TTL:** 60 giây (clients sẽ cập nhật DNS cache)

**Configuration hiện tại (Route53 module):**
```hcl
# Primary Health Check
resource "aws_route53_health_check" "primary" {
  fqdn              = local.primary_health_check_target
  port              = 443  # or 80
  type              = "HTTPS"  # or "HTTP"
  failure_threshold = 3      # Fail after 3 checks
  request_interval  = 30     # Check every 30 seconds
  
  # Primary record chỉ được dùng nếu healthy
  failover_routing_policy {
    type = "PRIMARY"
  }
}

# Secondary record (fallback)
resource "aws_route53_record" "secondary_alias" {
  # Không có health check - luôn sẵn sàng
  failover_routing_policy {
    type = "SECONDARY"
  }
}
```

#### **Tầng 2: Database Layer (RDS Failover) - ⚠️ AUTOMATED PROMOTION**
- **Hiện tại:**
  - Secondary DB là **read-only** replica
  - Primary DB mất → RDS event subscription phát sinh sự kiện failover/failure
  - Lambda trong Terraform module nhận sự kiện và promote secondary

- **Khi failover xảy ra:**
  - Lambda kiểm tra trạng thái secondary DB
  - Nếu replica chưa được promote, Lambda gọi `PromoteReadReplica`
  - Secondary DB trở thành primary writable mới
  - Ứng dụng chuyển connection string sang endpoint secondary

- **Thời gian promotion:**
  - Thường mất khoảng 2-5 phút

**Sơ đồ hiện tại:**
```
Primary DB DOWN → Event Subscription emits failure/failover event
                ↓
            Lambda trigger
                ↓
      Promote read replica in secondary region
                ↓
          Replica becomes new Primary (writable)
                ↓
          Update app connection strings
```

### 2.3 Failover Workflow Chi Tiết

#### **Scenario: Primary RDS hoặc Primary Region bị sự cố**

```
1. PRIMARY REGION FAILURE
   ├─ Primary Database DOWN or unreachable
   ├─ Application loses write capability
   └─ Read requests từ Secondary ALB vẫn OK (but data cũ)

2. APPLICATION LAYER FAILOVER (Automatic - ~30 sec)
   ├─ Route53 Health Check detect Primary ALB unhealthy
   ├─ Route53 switches DNS to Secondary ALB
   ├─ Clients reconnect to Secondary region
   └─ ✅ Traffic now flows to Secondary Region App

3. DATABASE LAYER FAILOVER (Automated trigger - 2-5 min)
  ├─ RDS event subscription emits failover/failure event
  ├─ Lambda receives SNS event and checks secondary replica state
  ├─ Lambda calls `PromoteReadReplica` in secondary region
  ├─ Wait for promotion (2-5 minutes)
  ├─ ✅ Secondary DB becomes Writable Primary
  └─ Application can now WRITE to Secondary region

4. COMPLETE FAILOVER (No Data Loss < 1 sec)
  ├─ ✅ Application Layer: Automatic
  ├─ ✅ Database Layer: Automated trigger + promotion
  └─ ⏱️  Total time: 30s (app) + 2-5m (db) = ~3 min

5. (OPTIONAL) RECOVERY & RESYNC
   ├─ Restore failed Primary region
   ├─ Resync data từ new Primary (ex-Secondary) → restored Primary
   └─ Failback to original Primary (nếu muốn)
```

---

## 3. Thời Gian Failover (RTO/RPO)

| Layer                           | Failure                    | Automatic?            | RTO   | RPO   |
| ------------------------------- | -------------------------- | --------------------- | ----- | ----- |
| **Application (ALB)**           | Primary ALB down           | ✅ Yes                 | ~30s  | 0     |
| **Database (Primary instance)** | Primary RDS down (in AZ)   | ✅ Yes (Multi-AZ)      | ~1-2m | 0     |
| **Database (Region)**           | Entire Primary region down | ⚠️ Triggered by Lambda | 2-5m  | < 1s  |
| **Overall App**                 | Primary region down        | ⚠️ Semi-Auto           | 30s   | < 1s* |

*\*RPO < 1s vì read replica lag < 1s trong hầu hết trường hợp*

---

## 4. Cách Tự Động Hoá Database Failover

### 4.1 Current Implementation: SNS-triggered Lambda Promotion

Terraform module `rds_failover_automation` triển khai:

- `aws_db_event_subscription` để nhận sự kiện failover/failure từ primary DB
- `aws_sns_topic` làm kênh trigger cho Lambda
- `aws_lambda_function` dùng `rds:PromoteReadReplica` để promote secondary
- `aws_cloudwatch_metric_alarm` theo dõi `ReplicaLag` của secondary DB

Luồng thực thi:

```
RDS Event Subscription → SNS Topic → Lambda Function
                                      ↓
                              Check replica state
                                      ↓
                           Promote read replica if needed
                                      ↓
                           Secondary becomes writable primary
```

### 4.2 CloudWatch Alarm for Replica Lag

- Alarm được tạo ở secondary region
- Mục tiêu là phát hiện replica lag vượt ngưỡng trước khi failover
- Alarm action gửi tới SNS topic cảnh báo riêng

### 4.3 Recovery Notes

- Nếu cần failback về region chính, nên tạo lại replica mới từ primary mới sau khi hệ thống ổn định
- Không dùng cùng một replica để promote đi promote lại nhiều lần
- Luôn kiểm tra replication lag trước khi mở write traffic cho ứng dụng

---

## 5. Current Gaps & Recommendations

### ⚠️ Limitations Hiện Tại:
1. **Database promotion vẫn cần vài phút** để replica chuyển thành primary.
2. **Failover trigger dựa trên RDS event subscription** trong region chính.
3. **Nếu mất hoàn toàn region chính**, trigger cần thêm lớp quan sát bên ngoài region đó để phát hiện outage.

### ✅ Recommendations (Priority):

**Tier 1 (Critical - Done):**
- [x] Thêm Lambda automation để promote replica tự động
- [x] Thêm CloudWatch alarm cho replication lag
- [x] Gắn RDS event subscription để trigger Lambda khi failover/failure xảy ra

**Tier 2 (Important - Later):**
- [ ] Cấu hình AWS Secrets Manager rotation cho DB credentials
- [ ] Thêm CloudWatch alarms cho replication lag
- [ ] Disaster recovery runbook & testing

**Tier 3 (Nice-to-have):**
- [ ] RDS Proxy cho connection pooling
- [ ] DMS setup cho zero-downtime migration

---

## 6. Monitoring Replication Health

### Key Metrics:
```hcl
# CloudWatch Metrics to monitor
- ReplicaLag                  # Secondary lag từ Primary (seconds)
- DatabaseConnections         # Number of active connections
- BinLogDiskUsage             # Binary log disk space
- NetworkReceiveThroughput    # Data being replicated
```

### Health Check Implementation:
```bash
# Check replication status
aws rds describe-db-instances \
  --db-instance-identifier ha-db-secondary \
  --query 'DBInstances[0].{Status:DBInstanceStatus, ReplicationRole:ReadReplicaSourceDBInstanceIdentifier}'

# Expected output:
# Status: available
# ReplicationRole: arn:aws:rds:ap-southeast-1:xxxxx:db:ha-db
```

---

## 7. Failover Testing Checklist

```
Pre-Failover:
  [ ] Verify replication lag < 1 second
  [ ] Test secondary DB read access
  [ ] Verify application can read from secondary
  [ ] Create snapshot of primary

Failover Test:
  [ ] Simulate primary region failure
  [ ] Verify Route53 switches to secondary
  [ ] Check application health in secondary
  [ ] Verify no data loss (compare records)
  [ ] Monitor replication lag after failover

Post-Failover:
  [ ] Restore primary region infrastructure
  [ ] Rebuild primary DB from backup
  [ ] Resync secondary → primary (optional)
  [ ] Update DNS if needed
  [ ] Document lessons learned
```

---

## 8. Quick Reference: RDS Failover Commands

```bash
# Check current replication status
aws rds describe-db-instances \
  --db-instance-identifier ha-db \
  --query 'DBInstances[0].ReadReplicaDBInstanceIdentifiers'

# Monitor replication lag
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=ha-db-secondary \
  --start-time 2026-05-14T00:00:00Z \
  --end-time 2026-05-14T01:00:00Z \
  --period 60 \
  --statistics Average

# Trigger promotion manually if needed
aws rds promote-read-replica \
  --db-instance-identifier ha-db-secondary \
  --backup-retention-period 7 \
  --apply-immediately
```

---

## Summary

| Aspect           | Current State                         | Auto?                                |
| ---------------- | ------------------------------------- | ------------------------------------ |
| **RDS Sync**     | Cross-region async replica (< 1s lag) | ✅ Auto                               |
| **App Failover** | Route53 health check + DNS switch     | ✅ Auto (30s)                         |
| **DB Failover**  | Lambda-triggered replica promotion    | ⚠️ Automated trigger (2-5m promotion) |
| **Data Loss**    | None (RPO < 1s)                       | ✅ Safe                               |
| **Overall RTO**  | ~3 minutes                            | ⚠️ Semi-Auto                          |

**Next Step:** Mở rộng trigger sang cơ chế ngoài region chính nếu bạn cần coverage cho tình huống mất toàn bộ region.
