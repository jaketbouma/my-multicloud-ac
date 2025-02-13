
# A module later if it makes sense... for now, locals will do fine
locals {
  aws_accounts = {
    "bookstore" = {
      project  = "bookstore"
      email = "${module.split_admin_email.parts.name}+bookstore@${module.split_admin_email.parts.domain}"
    }
    "platform" = {
      project  = "platform"
      email = "${module.split_admin_email.parts.name}+platform@${module.split_admin_email.parts.domain}"
    }
  }
}