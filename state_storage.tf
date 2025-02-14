data "aws_s3_bucket" "terraform_statefiles" {
  bucket = var.aws_statefile_bucket_name
}
