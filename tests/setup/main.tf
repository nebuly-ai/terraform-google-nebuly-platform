terraform {
  required_version = ">= 1.10"
}

variable "credentials" {
  type    = string
  default = null
}
output "credentials" {
  value     = var.credentials == null ? file("${path.module}/credentials.json") : var.credentials
  sensitive = true
}
