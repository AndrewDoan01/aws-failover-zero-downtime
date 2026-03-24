provider "aws" {
  region = var.aws_region
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
  source = "../modules/VPC"

  name            = var.vpc_name
  cidr            = var.vpc_cidr
  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  tags = local.common_tags
}

module "database" {
  source = "../modules/database"

  identifier = var.db_identifier
  db_name    = var.db_name
  username   = var.db_username
  password   = var.db_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  tags = local.common_tags
}

module "eks" {
  source = "../modules/eks"

  cluster_name = var.eks_cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  tags = local.common_tags
}

module "monitoring" {
  source = "../modules/monitoring"

  project_name     = var.project_name
  rds_instance_id  = module.database.db_instance_id
  eks_cluster_name = module.eks.cluster_name

  tags = local.common_tags
}

module "route53" {
  count  = var.enable_route53 ? 1 : 0
  source = "../modules/route53"

  zone_name      = var.route53_zone_name
  private_zone   = var.route53_private_zone
  record_name    = var.route53_record_name
  primary_record = var.route53_primary_record

  create_secondary_record = var.route53_create_secondary_record
  secondary_record        = var.route53_secondary_record
  primary_weight          = var.route53_primary_weight
  secondary_weight        = var.route53_secondary_weight
}
