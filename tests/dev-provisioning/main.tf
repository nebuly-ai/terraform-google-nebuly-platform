# ----------- Terraform setup ----------- #
terraform {
  required_version = ">1.8"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>6.3"
    }
  }
}

provider "google" {
  region      = var.region
  credentials = file("${path.module}/credentials.json")
  project     = "nbllab-platform-test"
}


# ------ Variables ------ #
variable "region" {
  type = string
}
variable "nebuly_credentials" {
  type = object({
    client_id     = string
    client_secret = string
  })
}


# ------ Main ------ #
module "platform" {
  source = "../.."

  region          = var.region
  resource_prefix = "dev-"

  postgres_server_delete_protection = false
  postgres_server_tier              = "db-f1-micro"
  postgres_server_high_availability = {
    enabled = false
  }

  gke_cluster_admin_users = [
    "m.zanotti@nebuly.ai",
  ]
  gke_delete_protection = false

  openai_api_key              = "my-key"
  openai_endpoint             = "https://api.openai.com"
  openai_gpt4_deployment_name = "gpt-4"

  platform_domain    = "platform.gcp.testing.nebuly.com"
  nebuly_credentials = var.nebuly_credentials
}

output "gke_cluster_get_credentials" {
  value = module.platform.gke_cluster_get_credentials
}
output "helm_values" {
  value = module.platform.helm_values
}
output "secret_provider_class" {
  value = module.platform.secret_provider_class
}
