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
# that provisions to all project accounts.
# giving AdministratorAccess managed policy,
# and via an inline policy,
#   permission to assume the ProjectAccess role in the root account

resource "aws_ssoadmin_permission_set" "terraform_developer" {
  name             = "TerraformDeveloperPermissionSet"
  description      = "Gives access to terraform projects"
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
  inline_policy      = data.aws_iam_policy_document.projects_assume_role_in_root.json
}
data "aws_iam_policy_document" "projects_assume_role_in_root" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      aws_iam_role.project_access.arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutBucketPolicy",
    ]
    resources = [
      "arn:aws:s3:::*"
    ]
  }
}
resource "aws_ssoadmin_account_assignment" "terraform_developer_to_projects" {
  for_each     = aws_organizations_account.project_accounts
  instance_arn = var.aws_sso_instance_arn

  permission_set_arn = aws_ssoadmin_permission_set.terraform_developer.arn

  principal_id   = aws_identitystore_group.terraform_developers.group_id
  principal_type = "GROUP"

  target_id   = each.value.id
  target_type = "AWS_ACCOUNT"
}


#
# Create a role in root account,
# that trusts project accounts,
# and gives access to root's Identity Store and statefiles via inline policy

data "aws_iam_policy_document" "project_to_root_inline" {
  statement {
    actions = [
      "identitystore:DescribeGroup",
      #"identitystore:CreateGroup",
      #"identitystore:DeleteGroup",
      #"identitystore:UpdateGroup",
      "identitystore:DescribeGroupMembership",
      #"identitystore:CreateGroupMembership",
      #"identitystore:DeleteGroupMembership",
      #"identitystore:UpdateGroupMembership"
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
      #"sso:*",
      #"sso:CreatePermissionSet",
      #"sso:UpdatePermissionSet",
      #"sso:DeletePermissionSet",
      "sso:DescribePermissionSet",
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
      for object in aws_s3_object.project_statefiles :
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
data "aws_iam_policy_document" "project_to_root_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type = "AWS"
      identifiers = [
        for account in aws_organizations_account.project_accounts : "arn:aws:iam::${account.id}:root"
      ]
    }
  }
}

resource "aws_iam_role" "project_access" {
  name               = "TerraformProjectAccess"
  description        = "Allows project accounts to access statefiles in the root account"
  assume_role_policy = data.aws_iam_policy_document.project_to_root_assume_role.json
}
resource "aws_iam_role_policy" "project_access" {
  role   = aws_iam_role.project_access.name
  policy = data.aws_iam_policy_document.project_to_root_inline.json
}
resource "aws_iam_role_policies_exclusive" "project_access" {
  role_name = aws_iam_role.project_access.name
  policy_names = [
    aws_iam_role_policy.project_access.name
  ]
}
