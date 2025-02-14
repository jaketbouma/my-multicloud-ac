terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  #
  # This backend is deployed in statestorage.tf,
  # comment this out when deploying for the first time, then adjust.
  backend "s3" {
    bucket         = ""
    key            = ""
    region         = ""
    profile        = ""
    use_lockfile   = true
    dynamodb_table = ""
  }
}

provider "aws" {
  region              = var.aws_default_region
  profile             = "root/OrganizationAdministrator"
  allowed_account_ids = [var.aws_root_account_id]
  default_tags {
    tags = {
      "environment" = "sandbox"
      "deployment"  = "iac"
      "iac"         = "terraform/my-multicloud-ac"
    }
  }
}
