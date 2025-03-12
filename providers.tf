terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

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

data "aws_s3_bucket" "terraform_statefiles" {
  bucket = var.aws_statefile_bucket_name
}