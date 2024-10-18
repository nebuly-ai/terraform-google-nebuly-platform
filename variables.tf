# ------ General ------ #
variable "region" {
  description = "The region where the resources will be created"
  type        = string
}
variable "labels" {
  type        = map(string)
  default     = {}
  description = "Common labels that will be applied to all resources."
}
variable "resource_prefix" {
  type        = string
  description = "The prefix that is used for generating resource names."
}
variable "platform_domain" {
  type        = string
  description = "The domain on which the deployed Nebuly platform is made accessible."
  validation {
    condition     = can(regex("(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]", var.platform_domain))
    error_message = "The domain name must be a valid domain (e.g., example.com)."
  }
}
variable "openai_endpoint" {
  description = "The endpoint of the OpenAI API."
  type        = string
}
variable "openai_gpt4_deployment_name" {
  description = "The name of the deployment to use for the GPT-4 model."
  type        = string
}


# ------ Networking ------ #
variable "network_cidr_blocks" {
  description = <<EOT
  The CIDR blocks of the VPC network used by Nebuly.

  - primary: The primary CIDR block of the VPC network.
  - secondary_gke_pods: The secondary CIDR block used by GKE for pods.
  - secondary_gke_services: The secondary CIDR block used by GKE for services.
  EOT
  type = object({
    primary : string
    secondary_gke_pods : string
    secondary_gke_services : string
  })
  default = {
    primary                = "10.0.0.0/16"
    secondary_gke_pods     = "10.4.0.0/16"
    secondary_gke_services = "10.6.0.0/16"
  }
}


# ------ PostgreSQL ------ #
variable "postgres_server_tier" {
  description = "The tier of the PostgreSQL server. Default value: 4 vCPU, 16GB memory."
  type        = string
  default     = "db-custom-4-15360"
}
variable "postgres_server_delete_protection" {
  description = "Whether the PostgreSQL server should have delete protection enabled."
  type        = bool
  default     = true
}
variable "postgres_server_maintenance_window" {
  description = "Time window when the PostgreSQL server can automatically restart to apply updates. Specified in UTC time."
  type = object({
    day : string
    hour : number
  })
  default = {
    day  = "6" # Saturday
    hour = 23  # 23:00 UTC
  }
}
variable "postgres_server_edition" {
  description = "The edition of the PostgreSQL server. Possible values are ENTERPRISE, ENTERPRISE_PLUS."
  type        = string
  default     = "ENTERPRISE"
  validation {
    condition     = can(regex("^(ENTERPRISE|ENTERPRISE_PLUS)$", var.postgres_server_edition))
    error_message = "The edition must be either ENTERPRISE or ENTERPRISE_PLUS."
  }
}
variable "postgres_server_disk_size" {
  description = "The size of the disk in GB for the PostgreSQL server."
  type = object({
    initial = number
    limit   = number
  })
  default = {
    initial = 16
    limit   = 1000
  }
  validation {
    condition     = var.postgres_server_disk_size.initial < var.postgres_server_disk_size.limit
    error_message = "The initial disk size must be less than the limit."
  }
}
variable "postgres_server_backup_configuration" {
  description = "The backup settings of the PostgreSQL server."
  type = object({
    enabled                        = bool
    point_in_time_recovery_enabled = bool
    n_retained_backups             = number
  })
  default = {
    enabled                        = true
    point_in_time_recovery_enabled = true
    n_retained_backups             = 14
  }
}
variable "postgres_server_high_availability" {
  description = "The high availability configuration for the PostgreSQL server."
  type = object({
    enabled : bool
  })
  default = {
    enabled = true
  }
}


# ------ GKE ------ #
variable "gke_service_account_name" {
  description = "The name of the Kubernetes Service Account used by Nebuly installation."
  default     = "nebuly"
  type        = string
}
variable "gke_kubernetes_version" {
  description = "The used Kubernetes version for the GKE cluster."
  type        = string
  default     = "1.30.3"
}
variable "gke_delete_protection" {
  description = "Whether the GKE Cluster should have delete protection enabled."
  type        = bool
  default     = true
}
variable "gke_nebuly_namespaces" {
  description = "The namespaces used by Nebuly installation. Update this if you use custom namespaces in the Helm chart installation."
  type        = set(string)
  default     = ["nebuly", "nebuly-bootstrap"]
}
variable "gke_node_pools" {
  description = <<EOT
  The node Pools used by the GKE cluster.
  EOT
  type = map(object({
    machine_type   = string
    min_nodes      = number
    max_nodes      = number
    node_count     = number
    node_locations = optional(set(string), null)
    preemptible    = optional(bool, false)
    labels         = optional(map(string), {})
    taints = optional(set(object({
      key    = string
      value  = string
      effect = string
    })), null)
    guest_accelerator = optional(object({
      type  = string
      count = number
    }), null)
  }))
  default = {
    "web-services" : {
      machine_type = "n4-highmem-4"
      min_nodes    = 1
      max_nodes    = 1
      node_count   = 1
    }
    "gpu-primary" : {
      machine_type = "g2-standard-8"
      min_nodes    = 0
      max_nodes    = 1
      node_count   = null
      guest_accelerator = {
        type  = "nvidia-l4"
        count = 1
      }
      labels = {
        "gke-no-default-nvidia-gpu-device-plugin" : true,
        "nebuly.com/accelerator" : "nvidia-l4",
      }
    }
    "gpu-secondary" : {
      machine_type = "n1-standard-4"
      min_nodes    = 0
      max_nodes    = 1
      node_count   = null
      guest_accelerator = {
        type  = "nvidia-tesla-t4"
        count = 1
      }
      labels = {
        "gke-no-default-nvidia-gpu-device-plugin" : true,
        "nebuly.com/accelerator" : "nvidia-tesla-t4",
      }
    }
  }
}
variable "gke_cluster_admin_users" {
  description = "The list of email addresses of the users who will have admin access to the GKE cluster."
  type        = set(string)
}


# ------ External credentials ------ #
variable "openai_api_key" {
  description = "The API Key used for authenticating with OpenAI."
  type        = string
  validation {
    condition     = length(var.openai_api_key) > 0
    error_message = "The OpenAI API Key must be provided."
  }
}
variable "nebuly_credentials" {
  type = object({
    client_id : string
    client_secret : string
  })
  description = <<EOT
  The credentials provided by Nebuly are required for activating your platform installation. 
  If you haven't received your credentials or have lost them, please contact support@nebuly.ai.
  EOT

  validation {
    condition = alltrue([
      length(var.nebuly_credentials.client_id) > 0,
      length(var.nebuly_credentials.client_secret) > 0
    ])
    error_message = "The client_id and client_secret must be provided."
  }
}
variable "k8s_image_pull_secret_name" {
  description = <<EOT
  The name of the Kubernetes Image Pull Secret to use. 
  This value will be used to auto-generate the values.yaml file for installing the Nebuly Platform Helm chart.
  EOT
  type        = string
  default     = "nebuly-docker-pull"
}
