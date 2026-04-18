provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

provider "aws" {
  alias      = "secondary"
  region     = var.dr_aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

locals {
  base_tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "Terraform"
    },
    var.tags
  )

  primary_common_tags = merge(local.base_tags, {
    RegionRole = "primary"
    Region     = var.aws_region
  })

  secondary_common_tags = merge(local.base_tags, {
    RegionRole = "secondary"
    Region     = var.dr_aws_region
  })

  primary_cluster_tags = merge(local.primary_common_tags, {
    Service     = "eks"
    ClusterRole = "primary"
  })

  secondary_cluster_tags = merge(local.secondary_common_tags, {
    Service     = "eks"
    ClusterRole = "secondary"
  })
}

module "primary_vpc" {
  source = "./modules/VPC"

  name            = var.vpc_name
  cidr            = var.vpc_cidr
  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  tags = merge(local.primary_common_tags, {
    Service = "vpc"
  })
}

module "primary_database" {
  source = "./modules/database"

  identifier = var.db_identifier
  db_name    = var.db_name
  username   = var.db_username
  password   = var.db_password

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

  cluster_name = var.eks_cluster_name
  vpc_id       = module.primary_vpc.vpc_id
  subnet_ids   = module.primary_vpc.private_subnet_ids

  tags = local.primary_cluster_tags
}

module "secondary_vpc" {
  count = var.enable_passive_cluster ? 1 : 0

  providers = {
    aws = aws.secondary
  }

  source = "./modules/VPC"

  name            = var.secondary_vpc_name
  cidr            = var.secondary_vpc_cidr
  azs             = var.secondary_vpc_azs
  private_subnets = var.secondary_vpc_private_subnets
  public_subnets  = var.secondary_vpc_public_subnets

  tags = merge(local.secondary_common_tags, {
    Service = "vpc"
  })
}

module "secondary_eks" {
  count = var.enable_passive_cluster ? 1 : 0

  providers = {
    aws = aws.secondary
  }

  source = "./modules/eks"

  cluster_name           = var.passive_eks_cluster_name
  vpc_id                 = module.secondary_vpc[0].vpc_id
  subnet_ids             = module.secondary_vpc[0].private_subnet_ids
  node_desired_size      = var.passive_node_desired_size
  node_min_size          = var.passive_node_min_size
  node_max_size          = var.passive_node_max_size
  endpoint_public_access = true

  tags = local.secondary_cluster_tags
}

resource "aws_resourcegroups_group" "primary_eks_cluster" {
  count = var.create_cluster_resource_groups ? 1 : 0

  name = "${var.project_name}-primary-eks-cluster-rg"

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
  count = var.create_cluster_resource_groups && var.enable_passive_cluster ? 1 : 0

  provider = aws.secondary

  name = "${var.project_name}-secondary-eks-cluster-rg"

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

  github_org                       = var.github_org
  github_repo                      = var.github_repo
  role_name_prefix                 = var.oidc_role_name_prefix
  environments                     = var.oidc_deploy_environments
  create_github_oidc_provider      = var.create_github_oidc_provider
  github_oidc_provider_arn         = var.github_oidc_provider_arn
  aws_region                       = var.aws_region
  eks_cluster_name                 = var.eks_cluster_name
  secondary_aws_region             = var.dr_aws_region
  secondary_eks_cluster_name       = var.passive_eks_cluster_name
  enable_secondary_eks_permissions = var.enable_passive_cluster

  tags = local.base_tags
}
