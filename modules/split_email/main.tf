# No resources needed, just outputs based on the input variable
locals {
    split_regex = "^(?<name>[^+@]+)(?:\\+(?<tag>[^@+]+))?@(?<domain>[^@+]+)$"
}