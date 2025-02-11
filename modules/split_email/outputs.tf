output "parts" {
  description = "The split email components; name, tag, domain" 
  value = regex(local.split_regex, var.email)
}
