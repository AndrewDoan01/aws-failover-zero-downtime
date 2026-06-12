provider "aws" {
  region = var.primary_region

  profile = var.aws_profile

  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  token      = var.aws_session_token
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  profile = var.aws_profile

  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  token      = var.aws_session_token
}

data "aws_caller_identity" "current" {}

locals {
  base_tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "Terraform"
    },
    var.tags
  )

  eks_admin_principal_arn = coalesce(var.eks_admin_principal_arn, data.aws_caller_identity.current.arn)

  primary_eks_access_entries = merge(
    {
      terraform-admin = {
        principal_arn = local.eks_admin_principal_arn

        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    { for env, arn in try(module.oidc_iam[0].role_arns, {}) : "deploy-${env}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    } }
  )

  primary_common_tags = merge(local.base_tags, {
    RegionRole = "primary"
    Region     = var.primary_region
  })

  secondary_common_tags = merge(local.base_tags, {
    RegionRole = "secondary"
    Region     = var.secondary_region
  })

  primary_cluster_tags = merge(local.primary_common_tags, {
    Service     = "eks"
    ClusterRole = "primary"
  })

  secondary_cluster_tags = merge(local.secondary_common_tags, {
    Service     = "eks"
    ClusterRole = "secondary"
  })

  route53_resolved_zone_name   = var.route53_zone_name == null || trimspace(var.route53_zone_name) == "" ? "example.local" : trimspace(var.route53_zone_name)
  route53_resolved_record_name = var.route53_record_name == null || trimspace(var.route53_record_name) == "" ? "retail-store-sample-app" : trimspace(var.route53_record_name)
}

module "primary_vpc" {
  source = "./modules/VPC"

  name            = var.vpc_primary_name
  cidr            = var.vpc_primary_cidr
  azs             = var.vpc_primary_azs
  private_subnets = var.vpc_primary_private_subnets
  public_subnets  = var.vpc_primary_public_subnets

  tags = merge(local.primary_common_tags, {
    Service = "vpc"
  })
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  tags = var.tags
}

module "primary_database" {
  source = "./modules/database"

  identifier  = var.db_identifier
  db_name     = var.db_name
  username    = var.db_username
  db_password = var.db_password

  vpc_id                     = module.primary_vpc.vpc_id
  subnet_ids                 = module.primary_vpc.private_subnet_ids
  allowed_cidr_blocks        = var.db_allowed_cidr_blocks
  allowed_security_group_ids = var.db_allowed_security_group_ids

  tags = merge(local.primary_common_tags, {
    Service = "database"
  })
}

module "primary_eks" {
  source = "./modules/eks"

  cluster_name   = var.eks_primary_region_cluster_name
  vpc_id         = module.primary_vpc.vpc_id
  subnet_ids     = module.primary_vpc.private_subnet_ids
  access_entries = local.primary_eks_access_entries

  tags = local.primary_cluster_tags
}

# Security group for primary ALB
resource "aws_security_group" "primary_alb" {
  name        = "${var.project_name}-primary-alb-sg"
  description = "Security group for primary ALB"
  vpc_id      = module.primary_vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.primary_common_tags, {
    Name = "${var.project_name}-primary-alb-sg"
  })
}

# Primary ALB
resource "aws_lb" "primary" {
  name               = "${var.project_name}-primary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.primary_alb.id]
  subnets            = module.primary_vpc.public_subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(local.primary_common_tags, {
    Name = "${var.project_name}-primary-alb"
  })
}

# Target group for primary ALB (pointing to EKS nodes)
resource "aws_lb_target_group" "primary" {
  name        = "${var.project_name}-primary-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.primary_vpc.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/health"
    matcher             = "200-399"
  }

  tags = merge(local.primary_common_tags, {
    Name = "${var.project_name}-primary-tg"
  })
}

# Listener for primary ALB
resource "aws_lb_listener" "primary_http" {
  load_balancer_arn = aws_lb.primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary.arn
  }
}

module "secondary_vpc" {
  count = var.enable_secondary_cluster ? 1 : 0

  providers = {
    aws = aws.secondary
  }

  source = "./modules/VPC"

  name            = var.vpc_secondary_name
  cidr            = var.vpc_secondary_cidr
  azs             = var.vpc_secondary_azs
  private_subnets = var.vpc_secondary_private_subnets
  public_subnets  = var.vpc_secondary_public_subnets

  tags = merge(local.secondary_common_tags, {
    Service = "vpc"
  })
}

module "secondary_eks" {
  count = var.enable_secondary_cluster ? 1 : 0

  providers = {
    aws = aws.secondary
  }

  source = "./modules/eks"

  cluster_name           = var.eks_secondary_region_cluster_name
  vpc_id                 = module.secondary_vpc[0].vpc_id
  subnet_ids             = module.secondary_vpc[0].private_subnet_ids
  access_entries         = local.primary_eks_access_entries
  node_desired_size      = var.eks_secondary_node_desired_size
  node_min_size          = var.eks_secondary_node_min_size
  node_max_size          = var.eks_secondary_node_max_size
  endpoint_public_access = true

  tags = local.secondary_cluster_tags
}


resource "aws_kms_key" "secondary_db" {
  count                   = var.enable_secondary_cluster ? 1 : 0
  provider                = aws.secondary
  description             = "KMS key for secondary database replica encryption"
  deletion_window_in_days = 7
}

module "secondary_database" {
  count = var.enable_secondary_cluster ? 1 : 0

  providers = {
    aws = aws.secondary
  }

  source = "./modules/database"

  identifier          = "${var.db_identifier}-secondary"
  vpc_id              = module.secondary_vpc[0].vpc_id
  subnet_ids          = module.secondary_vpc[0].private_subnet_ids
  replicate_source_db = module.primary_database.db_instance_arn
  kms_key_id          = aws_kms_key.secondary_db[0].arn

  tags = merge(local.secondary_common_tags, {
    Service      = "database"
    DatabaseRole = "read-replica"
  })
}

module "rds_failover_automation" {
  count = var.enable_secondary_cluster && var.enable_db_failover_automation ? 1 : 0

  providers = {
    aws           = aws
    aws.secondary = aws.secondary
  }

  source = "./modules/rds_failover_automation"

  project_name                       = var.project_name
  primary_db_identifier              = module.primary_database.db_instance_id
  secondary_db_identifier            = module.secondary_database[0].db_instance_id
  secondary_region                   = var.secondary_region
  rds_event_categories               = var.rds_failover_event_categories
  create_replication_lag_alarm       = var.enable_rds_replication_lag_alarm
  replication_lag_threshold_seconds  = var.rds_replication_lag_threshold_seconds
  replication_lag_evaluation_periods = var.rds_replication_lag_evaluation_periods
  replication_lag_period             = var.rds_replication_lag_period_seconds

  tags = local.base_tags
}

# Security group for secondary ALB
resource "aws_security_group" "secondary_alb" {
  count = var.enable_secondary_cluster ? 1 : 0

  provider    = aws.secondary
  name        = "${var.project_name}-secondary-alb-sg"
  description = "Security group for secondary ALB"
  vpc_id      = module.secondary_vpc[0].vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.secondary_common_tags, {
    Name = "${var.project_name}-secondary-alb-sg"
  })
}

# Secondary ALB
resource "aws_lb" "secondary" {
  count = var.enable_secondary_cluster ? 1 : 0

  provider           = aws.secondary
  name               = "NT114-secondary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.secondary_alb[0].id]
  subnets            = module.secondary_vpc[0].public_subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(local.secondary_common_tags, {
    Name = "${var.project_name}-secondary-alb"
  })
}

# Target group for secondary ALB
resource "aws_lb_target_group" "secondary" {
  count = var.enable_secondary_cluster ? 1 : 0

  provider    = aws.secondary
  name        = "NT114-secondary-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.secondary_vpc[0].vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/health"
    matcher             = "200-399"
  }

  tags = merge(local.secondary_common_tags, {
    Name = "${var.project_name}-secondary-tg"
  })
}

# Listener for secondary ALB
resource "aws_lb_listener" "secondary_http" {
  count = var.enable_secondary_cluster ? 1 : 0

  provider          = aws.secondary
  load_balancer_arn = aws_lb.secondary[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secondary[0].arn
  }
}

resource "aws_resourcegroups_group" "primary_eks_cluster" {
  count = var.create_cluster_resource_groups ? 1 : 0

  name = "rg-${var.project_name}-primary-eks-cluster"

  resource_query {
    type = "TAG_FILTERS_1_0"

    query = jsonencode({
      ResourceTypeFilters = [
        "AWS::EKS::Cluster",
        "AWS::EKS::Nodegroup"
      ]
      TagFilters = [
        {
          Key    = "Project"
          Values = [var.project_name]
        },
        {
          Key    = "Service"
          Values = ["eks"]
        },
        {
          Key    = "ClusterRole"
          Values = ["primary"]
        }
      ]
    })
  }

  tags = local.primary_cluster_tags
}

resource "aws_resourcegroups_group" "secondary_eks_cluster" {
  count = var.create_cluster_resource_groups && var.enable_secondary_cluster ? 1 : 0

  provider = aws.secondary

  name = "rg-${var.project_name}-secondary-eks-cluster"

  resource_query {
    type = "TAG_FILTERS_1_0"

    query = jsonencode({
      ResourceTypeFilters = [
        "AWS::EKS::Cluster",
        "AWS::EKS::Nodegroup"
      ]
      TagFilters = [
        {
          Key    = "Project"
          Values = [var.project_name]
        },
        {
          Key    = "Service"
          Values = ["eks"]
        },
        {
          Key    = "ClusterRole"
          Values = ["secondary"]
        }
      ]
    })
  }

  tags = local.secondary_cluster_tags
}

module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"

  project_name     = var.project_name
  alarm_topic_name = var.monitoring_alarm_topic_name
  rds_instance_id  = module.primary_database.db_instance_id
  eks_cluster_name = module.primary_eks.cluster_name

  prometheus_workspace_alias   = var.monitoring_prometheus_workspace_alias
  prometheus_logging_group_arn = var.monitoring_prometheus_logging_group_arn
  grafana_description          = var.monitoring_grafana_description

  tags = local.base_tags
}

module "route53" {
  count  = var.enable_route53 ? 1 : 0
  source = "./modules/route53"

  zone_name          = local.route53_resolved_zone_name
  private_zone       = var.route53_private_zone
  create_hosted_zone = var.route53_create_hosted_zone
  vpc_id             = module.primary_vpc.vpc_id
  record_name        = local.route53_resolved_record_name
  record_type        = var.route53_record_type
  create_alias       = true
  primary_record     = aws_lb.primary.dns_name

  primary_alias_name    = aws_lb.primary.dns_name
  primary_alias_zone_id = aws_lb.primary.zone_id

  create_secondary_record      = var.enable_secondary_cluster
  secondary_record             = var.enable_secondary_cluster ? aws_lb.secondary[0].dns_name : ""
  secondary_alias_name         = var.enable_secondary_cluster ? aws_lb.secondary[0].dns_name : ""
  secondary_alias_zone_id      = var.enable_secondary_cluster ? aws_lb.secondary[0].zone_id : ""
  alias_evaluate_target_health = var.route53_alias_evaluate_target_health

  primary_health_check_enabled           = var.route53_primary_health_check_enabled
  primary_health_check_fqdn              = aws_lb.primary.dns_name
  primary_health_check_port              = var.route53_primary_health_check_port
  primary_health_check_type              = var.route53_primary_health_check_type
  primary_health_check_resource_path     = var.route53_primary_health_check_resource_path
  primary_health_check_failure_threshold = var.route53_primary_health_check_failure_threshold
  primary_health_check_request_interval  = var.route53_primary_health_check_request_interval
  primary_health_check_enable_sni        = var.route53_primary_health_check_enable_sni
  primary_health_check_search_string     = var.route53_primary_health_check_search_string
  primary_health_check_regions           = var.route53_primary_health_check_regions

  secondary_health_check_enabled           = var.route53_secondary_health_check_enabled
  secondary_health_check_fqdn              = var.enable_secondary_cluster ? aws_lb.secondary[0].dns_name : ""
  secondary_health_check_port              = var.route53_secondary_health_check_port
  secondary_health_check_type              = var.route53_secondary_health_check_type
  secondary_health_check_resource_path     = var.route53_secondary_health_check_resource_path
  secondary_health_check_failure_threshold = var.route53_secondary_health_check_failure_threshold
  secondary_health_check_request_interval  = var.route53_secondary_health_check_request_interval
  secondary_health_check_enable_sni        = var.route53_secondary_health_check_enable_sni
  secondary_health_check_search_string     = var.route53_secondary_health_check_search_string
  secondary_health_check_regions           = var.route53_secondary_health_check_regions

  depends_on = [aws_lb.primary]
}

module "oidc_iam" {
  count  = var.enable_oidc_iam_roles ? 1 : 0
  source = "./modules/oidc_iam"

  github_org                        = var.github_org
  github_repo                       = var.github_repo
  role_name_prefix                  = var.oidc_role_name_prefix
  environments                      = var.oidc_deploy_environments
  create_github_oidc_provider       = var.create_github_oidc_provider
  github_oidc_provider_arn          = var.github_oidc_provider_arn
  primary_region                    = var.primary_region
  eks_primary_region_cluster_name   = var.eks_primary_region_cluster_name
  secondary_region                  = var.secondary_region
  eks_secondary_region_cluster_name = var.eks_secondary_region_cluster_name
  enable_secondary_eks_permissions  = var.enable_secondary_cluster

  tags = local.base_tags
}


module "ecr" {
  source = "./modules/ECR"

  repositories = [
    {
      name                 = "aws-retail-store-sample-app"
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
      tags = merge(local.base_tags, {
        Service = "ecr"
      })
    },
    {
      name                 = "aws-retail-store-sample-app-catalog"
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
      tags = merge(local.base_tags, {
        Service = "ecr"
      })
    },
    {
      name                 = "aws-retail-store-sample-app-cart"
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
      tags = merge(local.base_tags, {
        Service = "ecr"
      })
    },
    {
      name                 = "aws-retail-store-sample-app-checkout"
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
      tags = merge(local.base_tags, {
        Service = "ecr"
      })
    },
    {
      name                 = "aws-retail-store-sample-app-orders"
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
      tags = merge(local.base_tags, {
        Service = "ecr"
      })
    },
    {
      name                 = "aws-retail-store-sample-app-ui"
      image_tag_mutability = "IMMUTABLE"
      scan_on_push         = true
      tags = merge(local.base_tags, {
        Service = "ecr"
      })
    }
  ]

  tags = local.base_tags
}

module "github_ecr_role" {

  source = "./modules/oidc_ecr_role"


  github_org  = "AndrewDoan01"
  github_repo = "aws-retail-store-sample-app"

  environment = "dev"

  role_name = "github-actions-ecr-dev"

  repository_arns = values(module.ecr.repository_arns)

}

module "primary_postgres_database" {
  source = "./modules/database"

  identifier     = "${var.db_identifier}-postgres"
  db_name        = "orders"
  username       = "postgres"
  db_password    = var.db_password
  engine         = "postgres"
  engine_version = "16.9"
  port           = 5432

  vpc_id                     = module.primary_vpc.vpc_id
  subnet_ids                 = module.primary_vpc.private_subnet_ids
  allowed_cidr_blocks        = var.db_allowed_cidr_blocks
  allowed_security_group_ids = var.db_allowed_security_group_ids

  tags = merge(local.primary_common_tags, {
    Service = "database-postgres"
  })
}

module "secondary_postgres_database" {
  count = var.enable_secondary_cluster ? 1 : 0

  providers = {
    aws = aws.secondary
  }

  source = "./modules/database"

  identifier          = "${var.db_identifier}-postgres-secondary"
  vpc_id              = module.secondary_vpc[0].vpc_id
  subnet_ids          = module.secondary_vpc[0].private_subnet_ids
  replicate_source_db = module.primary_postgres_database.db_instance_arn
  kms_key_id          = aws_kms_key.secondary_db[0].arn

  tags = merge(local.secondary_common_tags, {
    Service      = "database-postgres"
    DatabaseRole = "read-replica"
  })
}

