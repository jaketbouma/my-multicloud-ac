variable "aws_root_account_id" {
  description = "The AWS root account ID"
  type        = string
}

variable "admin_email" {
  description = "The admin email address"
  type        = string
}

variable "aws_default_region" {
  description = "The default AWS region"
  type        = string
}

variable "aws_sso_instance_arn" {
  description = "The AWS SSO instance ARN"
  type        = string
}

variable "aws_sso_instance_identity_store_id" {
  description = "The AWS SSO instance identity store ID"
  type        = string
}

variable "aws_statefile_bucket_name" {
  description = "The name of the S3 bucket for Terraform state files"
  type        = string
}

variable "aws_sandbox_org_id" {
  description = "The organization ID under which sandbox accounts will be created"
  type        = string
}

variable "aws_idc_admin_user_ids" {
  description = "A list of Identity Center user IDs that will be admins of all sandboxes"
  type        = list(string)
}