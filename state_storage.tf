#
# S3 backend for this project and others
#

data "aws_s3_bucket" "terraform_statefiles" {
  bucket = var.aws_statefile_bucket_name
}

resource "aws_s3_bucket_policy" "terraform_statefiles_access" {
  # imported from clickops [x]
  bucket = data.aws_s3_bucket.terraform_statefiles.id
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
