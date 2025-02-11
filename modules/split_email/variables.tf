variable "email" {
  description = "The email address to split"
  type        = string
  validation {
    condition     = can(regex(local.split_regex, var.email))
    error_message = "Email format doesn't match format name+tag@domain"
  }
}
