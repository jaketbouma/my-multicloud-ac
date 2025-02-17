#
# Create an Identity Store group for terraform developers
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


#
# Create a permission set intended for the terraform-developers group,
# that provisions to all sandbox accounts.
# giving AdministratorAccess managed policy,
# and via an inline policy,
#   permission to assume the SandboxAccess role in the root account

resource "aws_ssoadmin_permission_set" "terraform_developer" {
  name             = "TerraformDeveloperPermissionSet"
  description      = "Gives access to terraform sandboxes"
  instance_arn     = var.aws_sso_instance_arn
  session_duration = "PT8H"
}
resource "aws_ssoadmin_managed_policy_attachment" "terraform_developer_gets_admin" {
  instance_arn       = var.aws_sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.terraform_developer.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
resource "aws_ssoadmin_permission_set_inline_policy" "terraform_developer_gets_inline" {
  instance_arn       = var.aws_sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.terraform_developer.arn
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
resource "aws_ssoadmin_account_assignment" "terraform_developer_to_sandboxes" {
  for_each     = aws_organizations_account.sandbox_accounts
  instance_arn = var.aws_sso_instance_arn

  permission_set_arn = aws_ssoadmin_permission_set.terraform_developer.arn

  principal_id   = aws_identitystore_group.terraform_developers.group_id
  principal_type = "GROUP"

  target_id   = each.value.id
  target_type = "AWS_ACCOUNT"
}


#
# Create a role in root account,
# that trusts sandbox accounts,
# and gives access to root's Identity Store and statefiles via inline policy

data "aws_iam_policy_document" "sandbox_to_root_inline" {
  statement {
    actions = [
      "identitystore:DescribeGroup",
      "identitystore:CreateGroup",
      "identitystore:DeleteGroup",
      "identitystore:UpdateGroup",
      "identitystore:DescribeGroupMembership",
      "identitystore:CreateGroupMembership",
      "identitystore:DeleteGroupMembership",
      "identitystore:UpdateGroupMembership"
    ]
    resources = [
      "arn:aws:identitystore::${var.aws_root_account_id}:identitystore/${var.aws_sso_instance_identity_store_id}",
      "arn:aws:identitystore:::group/*",
      "arn:aws:identitystore:::user/*",
      "arn:aws:identitystore:::membership/*"
    ]
  }
  statement {
    actions = [
      "sso:*",
      #"sso:CreatePermissionSet",
      #"sso:UpdatePermissionSet",
      #"sso:DeletePermissionSet",
      #"sso:DescribePermissionSet",
    ]
    # can narrow this down to the instance in question
    resources = ["*"]
    #condition {
    #  test     = "StringEquals"
    #  variable = "aws:ResourceTag/project"
    #  values   = toset([for account in local.aws_accounts : account.project])
    #}
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = concat([
      for object in aws_s3_object.sandbox_statefiles :
      "arn:aws:s3:::${object.bucket}/${object.key}*"
    ], ["arn:aws:s3:::${data.aws_s3_bucket.terraform_statefiles.id}"])
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

