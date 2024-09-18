terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>6.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}

variable "credentials" {
  type = string
  default = null
}
output "credentials" {
  value = var.credentials == null ?  file("${path.module}/credentials.json") : var.credentials
  sensitive = true
}
