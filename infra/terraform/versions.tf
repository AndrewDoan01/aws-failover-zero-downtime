terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Temporary: kubernetes provider is disabled until EKS is deployed.
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "~> 2.30"
    # }

    # helm = {
    # source  = "hashicorp/helm"
    # version = "~> 2.15"
    # }
  }
}
