#
# S3 backend for this project and others
#

resource "aws_s3_bucket" "terraform_statefiles" {
  # imported from clickops [x]
  bucket = var.aws_statefile_bucket_name
  tags = {
    "environment" = "production"
    "component"   = "terraform"
  }
}

resource "aws_s3_bucket_policy" "terraform_statefiles_access" {
  # imported from clickops [x]
  bucket = aws_s3_bucket.terraform_statefiles.id
  policy = data.aws_iam_policy_document.terraform_statefiles_access.json
}

data "aws_iam_policy_document" "terraform_statefiles_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_root_account_id}:root"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      "arn:aws:s3:::${var.aws_statefile_bucket_name}"
    ]
  }
}

resource "aws_s3_object" "statefile_cloud-management" {
  #imported from clickops [x]
  bucket = aws_s3_bucket.terraform_statefiles.id
  key    = "cloud-management/"
  tags = {
    "environment" = "production"
    "component"   = "terraform"
  }
}

resource "aws_dynamodb_table" "statelock_cloud-management" {
  #imported from clickops [x]
  name           = "terraform.statelock.cloud-management"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    "environment" = "production"
    "component"   = "terraform"
  }
}