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
    bucket         = "my-terraform-statefiles"
    key            = "cloud-management/terraform.tfstate"
    region         = "eu-north-1"
    profile        = "root/OrganizationAdministrator"
    use_lockfile   = true
    dynamodb_table = "terraform.statelock.cloud-management"
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
      "iac"         = "terraform/cloud-management"
    }
  }
}


#
# Create a policy set to give access to all terraform sandboxes

resource "aws_ssoadmin_permission_set" "sandboxes" {
  name             = "TerraformSandboxes"
  description      = "Gives access to terraform sandboxes"
  instance_arn     = var.aws_sso_instance_arn
  session_duration = "PT8H"
}
resource "aws_ssoadmin_managed_policy_attachment" "sandboxes" {
  instance_arn       = var.aws_sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sandboxes.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
resource "aws_identitystore_group" "terraform_developers" {
  identity_store_id = var.aws_sso_instance_identity_store_id
  display_name      = "terraform_developers"
  description       = "Users who can administer terraform sandboxes"
}
resource "aws_identitystore_group_membership" "terraform_developers_membership" {
  for_each = toset(var.aws_idc_admin_user_ids)
  identity_store_id = var.aws_sso_instance_identity_store_id
  group_id = aws_identitystore_group.terraform_developers.group_id
  member_id = each.key
}

module "split_admin_email" {
  source = "./modules/split_email"
  email  = var.admin_email
}

#
# Create a state backend for every aws sandbox project
resource "aws_organizations_account" "sandbox_accounts" {
  for_each = local.aws_accounts
  name              = each.key
  email             = each.value.email
  role_name         = "Admin"
  close_on_deletion = true
  parent_id         = var.aws_sandbox_org_id
  tags = {
    "project" = each.value.project
  }
}
resource "aws_s3_object" "sandbox_statefiles" {
  for_each = local.aws_accounts
  bucket = aws_s3_bucket.terraform_statefiles.id
  key    = "${each.key}/"
  tags = {
    "project"   = each.value.project
    "component" = "terraform"
  }
}
resource "aws_dynamodb_table" "sandbox_statelocks" {
  for_each = local.aws_accounts
  name           = "terraform.statelock.${each.key}"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    "project"   = each.value.project
    "component" = "terraform"
  }
}

# Grant the terraform_developers group admin access to all of the sandboxes
resource "aws_ssoadmin_account_assignment" "sandbox_access" {
  for_each = aws_organizations_account.sandbox_accounts
  instance_arn       = var.aws_sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sandboxes.arn

  principal_id   = aws_identitystore_group.terraform_developers.group_id
  principal_type = "GROUP"

  target_id   = each.value.id
  target_type = "AWS_ACCOUNT"
}
