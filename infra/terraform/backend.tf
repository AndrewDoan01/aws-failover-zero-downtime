terraform {
  required_version = "1.14.8"

  cloud {
    
    organization = "NT114_aws"

    workspaces {
      name = "AWS_IaC"
    }
  }
}