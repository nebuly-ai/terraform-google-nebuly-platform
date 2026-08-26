# ----------- Terraform setup ----------- #
terraform {
  required_version = ">1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>7.46"
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
variable "microsoft_sso" {
  type = object({
    tenant_id     = string
    client_id     = string
    client_secret = string
  })
  default = null
}
variable "nebuly_credentials" {
  type = object({
    client_id     = string
    client_secret = string
  })
}

variable "openai_api_key" {
  type = string
}


# ------ Main ------ #
module "platform" {
  source = "../.."

  region          = var.region
  resource_prefix = "dev-"

  gke_cluster_admin_users = [
    "d.cantella@nebuly.ai",
  ]
  gke_delete_protection = false
  # gke_private_cluster_config = {
  #   enable_private_nodes    = true
  #   enable_private_endpoint = true
  #   master_ipv4_cidr_block  = "172.172.16.0/28"
  # }

  openai_api_key                     = var.openai_api_key
  openai_endpoint                    = "https://api.openai.com/v1"
  openai_gpt4o_deployment_name       = "gpt-4o"
  openai_gpt5_deployment_name        = "gpt-5"
  openai_translation_deployment_name = "gpt-4o-mini"

  microsoft_sso = var.microsoft_sso

  platform_domain    = "platform.gcp.testing.nebuly.com"
  nebuly_credentials = var.nebuly_credentials

  gke_kubernetes_version = "1.36."
  gke_node_pools = {
    "web-services" : {
      machine_type = "n2-highmem-4"
      min_nodes    = 1
      max_nodes    = 1
      node_count   = 1
      resource_labels = {
        "goog-gke-node-pool-provisioning-model" = "on-demand"
      }
    }
    "clickhouse" : {
      machine_type = "n2-highmem-4"
      min_nodes    = 1
      max_nodes    = 1
      node_count   = 1
      disk_type    = "pd-ssd"
      disk_size_gb = 128
      resource_labels = {
        "goog-gke-node-pool-provisioning-model" = "on-demand"
      }
      labels = {
        "nebuly.com/reserved" : "clickhouse"
      }
      taints = [
        {
          key    = "nebuly.com/reserved"
          value  = "clickhouse"
          effect = "NO_SCHEDULE"
        }
      ]
    }
    "gpu-primary" : {
      machine_type = "a2-highgpu-1g"
      min_nodes    = 0
      max_nodes    = 1
      node_count   = null
      node_locations = [
        "europe-west4-a",
        "europe-west4-b",
      ]
      guest_accelerator = {
        type  = "nvidia-tesla-a100"
        count = 1
      }
      labels = {
        "gke-no-default-nvidia-gpu-device-plugin" : true,
        "nebuly.com/accelerator" : "nvidia-tesla-a100",
      }
      resource_labels = {
        "goog-gke-accelerator-type"             = "nvidia-tesla-a100"
        "goog-gke-node-pool-provisioning-model" = "on-demand"
      }
    }
  }
}

output "gke_cluster_get_credentials" {
  value = module.platform.gke_cluster_get_credentials
}
output "helm_values" {
  value = module.platform.helm_values
  sensitive = true
}
output "secret_provider_class" {
  value = module.platform.secret_provider_class
  sensitive = true
}
