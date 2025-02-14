

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
resource "aws_ssoadmin_permission_set_inline_policy" "sandboxes" {
  instance_arn       = var.aws_sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sandboxes.arn
  inline_policy      = data.aws_iam_policy_document.sandboxes_assume_role_in_root.json
}
data "aws_iam_policy_document" "sandboxes_assume_role_in_root" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      aws_iam_role.sandbox_access.arn
    ]
  }
}



#
# Create a policy set to give access to the identity store

data "aws_iam_policy_document" "sandbox_to_root_inline" {
  statement {
    actions = [
      "identitystore:CreateGroup",
      "identitystore:DeleteGroup",
      "identitystore:CreateGroupMembership",
      "identitystore:UpdateGroup",
      "identitystore:DescribeGroup"
    ]
    resources = [
      "arn:aws:identitystore::${var.aws_root_account_id}:identitystore/${var.aws_sso_instance_identity_store_id}",
      "arn:aws:identitystore:::group/*"
    ]
  }
  statement {
    actions = [
      "s3:*"
    ]
    resources = ["arn:aws:s3:::${data.aws_s3_bucket.terraform_statefiles.id}/*"]
  }
  statement {
    actions = [
      "dynamodb:*"
    ]
    resources = ["arn:aws:dynamodb:*:*:table/terraform.statelock.*"]
  }
}
data "aws_iam_policy_document" "sandbox_to_root_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type = "AWS"
      identifiers = [
        for account in aws_organizations_account.sandbox_accounts : "arn:aws:iam::${account.id}:root"
      ]
    }
  }
}
resource "aws_iam_role" "sandbox_access" {
  name               = "SandboxAccess"
  description        = "Allows sandbox accounts to access IdC and statefiles in the root account"
  assume_role_policy = data.aws_iam_policy_document.sandbox_to_root_assume_role.json
  inline_policy {
    name   = "SandboxToRootInlinePolicy"
    policy = data.aws_iam_policy_document.sandbox_to_root_inline.json
  }
}


#
#
resource "aws_identitystore_group" "terraform_developers" {
  identity_store_id = var.aws_sso_instance_identity_store_id
  display_name      = "terraform_developers"
}
resource "aws_identitystore_group_membership" "terraform_developers_membership" {
  for_each          = toset(var.aws_idc_admin_user_ids)
  identity_store_id = var.aws_sso_instance_identity_store_id
  group_id          = aws_identitystore_group.terraform_developers.group_id
  member_id         = each.key
}

module "split_admin_email" {
  source = "./modules/split_email"
  email  = var.admin_email
}

#
# Create a state backend for every aws sandbox project
resource "aws_organizations_account" "sandbox_accounts" {
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
resource "aws_s3_object" "sandbox_statefiles" {
  for_each = local.aws_accounts
  bucket   = data.aws_s3_bucket.terraform_statefiles.id
  key      = "${each.key}/"
  tags = {
    "project"   = each.value.project
    "component" = "terraform"
  }
}
resource "aws_dynamodb_table" "sandbox_statelocks" {
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

# Grant the terraform_developers group admin access to all of the sandboxes
resource "aws_ssoadmin_account_assignment" "sandbox_access" {
  for_each           = aws_organizations_account.sandbox_accounts
  instance_arn       = var.aws_sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sandboxes.arn

  principal_id   = aws_identitystore_group.terraform_developers.group_id
  principal_type = "GROUP"

  target_id   = each.value.id
  target_type = "AWS_ACCOUNT"
}
