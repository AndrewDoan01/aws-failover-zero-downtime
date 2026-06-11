# Build a dedicated subnet group so each RDS instance only uses the approved private subnets.
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# Allow application and peer security groups to reach the database port.
resource "aws_security_group" "db" {
  name        = "${var.identifier}-db-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = toset(var.allowed_cidr_blocks)
    content {
      description = "Database ingress from CIDR ${ingress.value}"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = toset(var.allowed_security_group_ids)
    content {
      description     = "Database ingress from security group ${ingress.value}"
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-db-sg"
  })
}

# Provision the managed database instance with encrypted storage and retained backups.
resource "aws_db_instance" "this" {
  identifier                 = var.identifier
  replicate_source_db        = var.replicate_source_db
  engine                     = var.replicate_source_db == null ? var.engine : null
  engine_version             = var.replicate_source_db == null ? var.engine_version : null
  instance_class             = var.instance_class
  allocated_storage          = var.replicate_source_db == null ? var.allocated_storage : null
  max_allocated_storage      = var.replicate_source_db == null ? var.max_allocated_storage : null
  db_name                    = var.replicate_source_db == null ? var.db_name : null
  username                   = var.replicate_source_db == null ? var.username : null
  password                   = var.replicate_source_db == null ? var.db_password : null
  port                       = var.replicate_source_db == null ? var.port : null
  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  multi_az                   = var.replicate_source_db == null ? var.multi_az : false
  publicly_accessible        = var.publicly_accessible
  storage_encrypted          = true
  backup_retention_period    = var.replicate_source_db == null ? var.backup_retention_period : 3
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.identifier}-final"
  deletion_protection        = !var.skip_final_snapshot
  apply_immediately          = true
  auto_minor_version_upgrade = true

  lifecycle {
    ignore_changes = [
      replicate_source_db,
    ]
  }

  tags = var.tags
}
