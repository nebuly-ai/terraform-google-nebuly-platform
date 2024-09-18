# ------ Variables ------ #
variable "region" {
  type    = string
  default = "us-central1"
}
variable "project" {
  type = string
}


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
  region  = var.region
  project = var.project
}


# ------ Main ------ #
module "nebuly" {
  source  = "nebuly-ai/nebuly-platform/gcp"
  version = "~0.1.0"

  region          = var.region
  resource_prefix = "dev-"

  gke_cluster_admin_users = [
    "your-user@email.com",
  ]

  openai_api_key              = "my-key"
  openai_endpoint             = "https://api.openai.com"
  openai_gpt4_deployment_name = "gpt-4"
  nebuly_credentials = {
    client_id     = "<your-nebuly-client-id>"
    client_secret = "<your-nebuly-client-secret>"
  }
}


# ------ Outputs ------ #
output "helm_values_bootstrap" {
  value       = module.nebuly.helm_values_bootstrap
  sensitive   = true
  description = <<EOT
  The `bootrap.values.yaml` file for installing the Nebuly Boostrap GCP chart with Helm.
  EOT
}
output "helm_values" {
  value       = module.nebuly.helm_values
  sensitive   = true
  description = <<EOT
  The `values.yaml` file for installing Nebuly with Helm.

  The default standard configuration is used, which uses Nginx as ingress controller and exposes the application to the Internet. This configuration can be customized according to specific needs.
  EOT
}
output "secret_provider_class" {
  value       = module.nebuly.secret_provider_class
  sensitive   = true
  description = "The `secret-provider-class.yaml` file to make Kubernetes reference the secrets stored in the Secrets Managethe Secrets Manager."
}
output "gke_cluster_get_credentials" {
  description = "Command for getting the credentials for accessing the Kubernetes Cluster."
  value       = module.nebuly.gke_cluster_get_credentials
}
