

module "split_admin_email" {
  source = "./modules/split_email"
  email  = var.admin_email
}

# A module later if it makes sense... for now, locals will do fine
locals {
  aws_accounts = {
    "bookstore" = {
      project = "bookstore"
      email   = "${module.split_admin_email.parts.name}+bookstore-001@${module.split_admin_email.parts.domain}"
    }
    "platform" = {
      project = "platform"
      email   = "${module.split_admin_email.parts.name}+platform-001@${module.split_admin_email.parts.domain}"
    }
  }
}


resource "aws_organizations_account" "project_accounts" {
  for_each          = local.aws_accounts
  name              = each.key
  email             = each.value.email
  role_name         = "Admin"
  close_on_deletion = true
  parent_id         = var.aws_sandbox_org_id
  tags = {
    "project" = each.value.project
  }
}

resource "aws_s3_object" "project_statefiles" {
  for_each = local.aws_accounts
  bucket   = data.aws_s3_bucket.terraform_statefiles.id
  key      = "${each.key}/"
  tags = {
    "project"   = each.value.project
    "component" = "terraform"
  }
}

resource "aws_dynamodb_table" "project_statelocks" {
  for_each       = local.aws_accounts
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
