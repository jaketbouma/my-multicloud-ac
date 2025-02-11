
# A module later if it makes sense... for now, locals will do fine
locals {
  aws_accounts = {
    "aws-v0-dev" = {
      project  = "aws-v0"
      email = "${module.split_admin_email.parts.name}+aws-v0-dev@${module.split_admin_email.parts.domain}"
    }
    "bookstore" = {
      project  = "bookstore"
      email = "${module.split_admin_email.parts.name}+bookstore@${module.split_admin_email.parts.domain}"
    }
  }
}