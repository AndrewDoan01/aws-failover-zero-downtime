terraform {

  cloud {

    organization = "NT114_aws"

    workspaces {
      name = "AWS_IaC"
    }
  }
}