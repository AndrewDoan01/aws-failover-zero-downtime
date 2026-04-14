provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

locals {
  common_tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

module "vpc" {
  source = "./modules/VPC"

  name            = var.vpc_name
  cidr            = var.vpc_cidr
  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  tags = local.common_tags
}

module "database" {
  source = "./modules/database"

  identifier = var.db_identifier
  db_name    = var.db_name
  username   = var.db_username
  password   = var.db_password

  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_cidr_blocks        = var.db_allowed_cidr_blocks
  allowed_security_group_ids = var.db_allowed_security_group_ids

  tags = local.common_tags
}

# Temporary: EKS module is disabled until deployment is ready.
module "eks" {
  source = "./modules/eks"

  cluster_name = var.eks_cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  tags = local.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name                     = var.project_name
  rds_instance_id                  = module.database.db_instance_id
  create_eks_failed_requests_alarm = false
  eks_cluster_name                 = module.eks.cluster_name

  tags = local.common_tags
}

module "route53" {
  count  = var.enable_route53 ? 1 : 0
  source = "./modules/route53"

  zone_name      = var.route53_zone_name
  private_zone   = var.route53_private_zone
  record_name    = var.route53_record_name
  record_type    = var.route53_record_type
  primary_record = var.route53_primary_record
  create_alias   = var.route53_create_alias

  primary_alias_name    = var.route53_primary_alias_name
  primary_alias_zone_id = var.route53_primary_alias_zone_id

  create_secondary_record      = var.route53_create_secondary_record
  secondary_record             = var.route53_secondary_record
  secondary_alias_name         = var.route53_secondary_alias_name
  secondary_alias_zone_id      = var.route53_secondary_alias_zone_id
  alias_evaluate_target_health = var.route53_alias_evaluate_target_health
  primary_weight               = var.route53_primary_weight
  secondary_weight             = var.route53_secondary_weight
}

module "oidc_iam" {
  count  = var.enable_oidc_iam_roles ? 1 : 0
  source = "./modules/oidc_iam"

  github_org                  = var.github_org
  github_repo                 = var.github_repo
  role_name_prefix            = var.oidc_role_name_prefix
  environments                = var.oidc_deploy_environments
  create_github_oidc_provider = var.create_github_oidc_provider
  github_oidc_provider_arn    = var.github_oidc_provider_arn
  tf_state_bucket_name        = var.tf_state_bucket_name
  tf_lock_table_name          = var.tf_lock_table_name
  aws_region                  = var.aws_region
  eks_cluster_name            = var.eks_cluster_name

  tags = local.common_tags
}
