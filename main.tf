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


# ------ Data Sources ------ #
data "google_project" "current" {}
data "google_compute_zones" "available" {}
data "google_container_engine_versions" "main" {
  location       = var.region
  version_prefix = var.gke_kubernetes_version
}


locals {
  gke_cluster_name                 = "${var.resource_prefix}nebuly"
  secondary_ip_range_name_services = "${local.gke_cluster_name}-services"
  secondary_ip_range_name_pods     = "${local.gke_cluster_name}-pods"
}


# ------ Network ------ #
resource "google_compute_network" "main" {
  name                    = "${var.resource_prefix}nebuly"
  description             = "The VPC network for the Nebuly platform."
  auto_create_subnetworks = false
}
resource "google_compute_global_address" "main" {
  name          = "private-ips"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20 # 800 usable GCP services
  network       = google_compute_network.main.id
}
resource "google_compute_subnetwork" "main" {
  name          = "main"
  ip_cidr_range = var.network_cidr_blocks.primary
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = local.secondary_ip_range_name_services
    ip_cidr_range = var.network_cidr_blocks.secondary_gke_services
  }

  secondary_ip_range {
    range_name    = local.secondary_ip_range_name_pods
    ip_cidr_range = var.network_cidr_blocks.secondary_gke_pods
  }
}

# Private Service Access for Cloud SQL private IP
resource "google_service_networking_connection" "main" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.main.name]
}
resource "google_compute_network_peering_routes_config" "main" {
  peering              = google_service_networking_connection.main.peering
  network              = google_compute_network.main.name
  import_custom_routes = true
  export_custom_routes = true
}


# ------ PostgreSQL ------ #
resource "google_sql_database_instance" "main" {
  name             = "${var.resource_prefix}nebuly"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier = var.postgres_server_tier

    availability_type     = var.postgres_server_high_availability.enabled == true ? "REGIONAL" : "ZONAL"
    edition               = var.postgres_server_edition
    disk_autoresize_limit = var.postgres_server_disk_size.limit
    disk_size             = var.postgres_server_disk_size.initial

    user_labels = var.labels

    ip_configuration {
      ipv4_enabled    = "false"
      private_network = google_compute_network.main.id
    }

    maintenance_window {
      day          = var.postgres_server_maintenance_window.day
      hour         = var.postgres_server_maintenance_window.hour
      update_track = "stable"
    }

    backup_configuration {
      enabled                        = var.postgres_server_backup_configuration.enabled
      point_in_time_recovery_enabled = var.postgres_server_backup_configuration.point_in_time_recovery_enabled
      backup_retention_settings {
        retained_backups = var.postgres_server_backup_configuration.n_retained_backups
      }
    }
  }

  deletion_protection = var.postgres_server_delete_protection

  depends_on = [google_service_networking_connection.main]
}
# --- Analytics DB --- #
resource "google_sql_database" "analytics" {
  name      = "analytics"
  instance  = google_sql_database_instance.main.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}
resource "random_password" "analytics" {
  length           = 16
  special          = true
  override_special = "_%@"
}
resource "google_sql_user" "analytics" {
  name     = "analytics"
  instance = google_sql_database_instance.main.name
  password = random_password.analytics.result
}
resource "google_secret_manager_secret" "postgres_analytics_username" {
  secret_id = "${var.resource_prefix}postgres-analytics-username"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "postgres_analytics_username" {
  secret      = google_secret_manager_secret.postgres_analytics_username.id
  secret_data = google_sql_user.analytics.name
}
resource "google_secret_manager_secret" "postgres_analytics_password" {
  secret_id = "${var.resource_prefix}postgres-analytics-password"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "postgres_analytics_password" {
  secret      = google_secret_manager_secret.postgres_analytics_password.id
  secret_data = google_sql_user.analytics.password
}
# --- Auth DB --- #
resource "google_sql_database" "auth" {
  name      = "auth"
  instance  = google_sql_database_instance.main.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}
resource "random_password" "auth" {
  length           = 16
  special          = true
  override_special = "_%@"
}
resource "google_sql_user" "auth" {
  name     = "auth"
  instance = google_sql_database_instance.main.name
  password = random_password.auth.result
}
resource "google_secret_manager_secret" "postgres_auth_username" {
  secret_id = "${var.resource_prefix}postgres-auth-username"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "postgres_auth_username" {
  secret      = google_secret_manager_secret.postgres_auth_username.id
  secret_data = google_sql_user.auth.name
}
resource "google_secret_manager_secret" "postgres_auth_password" {
  secret_id = "${var.resource_prefix}postgres-auth-password"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "postgres_auth_password" {
  secret      = google_secret_manager_secret.postgres_auth_password.id
  secret_data = google_sql_user.auth.password
}


# ------ GKE ------ #
resource "google_container_cluster" "main" {
  name     = local.gke_cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  release_channel {
    channel = "UNSPECIFIED"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = local.secondary_ip_range_name_pods
    services_secondary_range_name = local.secondary_ip_range_name_services
  }

  workload_identity_config {
    workload_pool = "${data.google_project.current.project_id}.svc.id.goog"
  }

  secret_manager_config {
    # Add-on doesn't support Sync as Kubernetes Secret, so we install it separately.
    enabled = false
  }

  node_locations = [
    # Limit to a single location the default node pool that gets deleted after provisioning the GKE cluster.
    data.google_compute_zones.available.names[0],
  ]

  min_master_version  = data.google_container_engine_versions.main.latest_master_version
  deletion_protection = var.gke_delete_protection

  depends_on = [
    google_compute_subnetwork.main,
  ]
}
resource "google_service_account" "gke_node_pool" {
  account_id   = "nebuly-gke-node-pools"
  display_name = "Service Account used by GKE Node Pools."
}
resource "google_container_node_pool" "main" {
  for_each = var.gke_node_pools

  name       = each.key
  cluster    = google_container_cluster.main.id
  location   = var.region
  node_count = each.value.node_count
  node_locations = (
    each.value.node_locations == null ?
    [data.google_compute_zones.available.names[0]] :
    each.value.node_locations
  )

  autoscaling {
    total_min_node_count = each.value.min_nodes
    total_max_node_count = each.value.max_nodes
    location_policy      = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = false
  }

  node_config {
    preemptible  = each.value.preemptible
    machine_type = each.value.machine_type

    service_account = google_service_account.gke_node_pool.email

    labels = each.value.labels

    dynamic "taint" {
      for_each = each.value.taints == null ? [] : each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    dynamic "guest_accelerator" {
      for_each = each.value.guest_accelerator == null ? {} : { "" : each.value.guest_accelerator }
      content {
        type  = guest_accelerator.value.type
        count = guest_accelerator.value.count

        gpu_driver_installation_config {
          gpu_driver_version = "INSTALLATION_DISABLED"
        }
      }
    }
  }


  lifecycle {
    ignore_changes = [
      node_config[0].kubelet_config,
    ]
  }
}
resource "google_project_iam_member" "gke_secret_accessors" {
  for_each = var.gke_nebuly_namespaces

  project = data.google_project.current.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${data.google_project.current.project_id}.svc.id.goog/subject/ns/${each.key}/sa/${var.gke_service_account_name}"

  depends_on = [
    google_container_cluster.main,
  ]
}
resource "google_storage_bucket_iam_binding" "gke_storage_object_user" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectUser"
  members = [
    for namespace in var.gke_nebuly_namespaces :
    "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${data.google_project.current.project_id}.svc.id.goog/subject/ns/${namespace}/sa/${var.gke_service_account_name}"
  ]

  depends_on = [
    google_container_cluster.main,
  ]
}
resource "google_project_iam_binding" "gke_cluster_admin" {
  count = length(var.gke_cluster_admin_users) > 0 ? 1 : 0

  project = data.google_project.current.project_id
  role    = "roles/container.clusterAdmin"

  members = [
    for user in var.gke_cluster_admin_users : "user:${user}"
  ]
}


# ------ Auth ------ #
resource "tls_private_key" "jwt_signing_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "google_secret_manager_secret" "jwt_signing_key" {
  secret_id = "${var.resource_prefix}jwt-signing-key"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "jwt_signing_key" {
  secret      = google_secret_manager_secret.jwt_signing_key.id
  secret_data = tls_private_key.jwt_signing_key.private_key_pem
}


# ------ External Credentials ------ #
resource "google_secret_manager_secret" "openai_api_key" {
  secret_id = "${var.resource_prefix}openai-api-key"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "openai_api_key" {
  secret      = google_secret_manager_secret.openai_api_key.id
  secret_data = var.openai_api_key
}
resource "google_secret_manager_secret" "nebuly_client_id" {
  secret_id = "${var.resource_prefix}nebuly-client-id"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "nebuly_client_id" {
  secret      = google_secret_manager_secret.nebuly_client_id.id
  secret_data = var.nebuly_credentials.client_id
}
resource "google_secret_manager_secret" "nebuly_client_secret" {
  secret_id = "${var.resource_prefix}nebuly-client-secret"
  labels    = var.labels

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "nebuly_client_secret" {
  secret      = google_secret_manager_secret.nebuly_client_secret.id
  secret_data = var.nebuly_credentials.client_secret
}

# ------ Storage ------ #
resource "google_storage_bucket" "main" {
  name                        = "${var.resource_prefix}nebuly"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  labels                      = var.labels
  storage_class               = "STANDARD"
}


# ------ Post provisioning ------ #
locals {
  secret_provider_class_name        = "nebuly-platform"
  secret_provider_class_secret_name = "nebuly-platform-credentials"

  # k8s secrets keys
  k8s_secret_key_analytics_db_username = "analytics-db-username"
  k8s_secret_key_analytics_db_password = "analytics-db-password"
  k8s_secret_key_auth_db_username      = "auth-db-username"
  k8s_secret_key_auth_db_password      = "auth-db-password"
  k8s_secret_key_jwt_signing_key       = "jwt-signing-key"
  k8s_secret_key_openai_api_key        = "openai-api-key"
  k8s_secret_key_nebuly_client_id      = "nebuly-azure-client-id"
  k8s_secret_key_nebuly_client_secret  = "nebuly-azure-client-secret"

  helm_values = templatefile(
    "${path.module}/templates/helm-values.tpl.yaml",
    {
      platform_domain        = var.platform_domain
      image_pull_secret_name = var.k8s_image_pull_secret_name

      openai_endpoint         = var.openai_endpoint
      openai_gpt4o_deployment = var.openai_gpt4_deployment_name

      secret_provider_class_name        = local.secret_provider_class_name
      secret_provider_class_secret_name = local.secret_provider_class_secret_name

      k8s_secret_key_analytics_db_username = local.k8s_secret_key_analytics_db_username
      k8s_secret_key_analytics_db_password = local.k8s_secret_key_analytics_db_password
      k8s_secret_key_auth_db_username      = local.k8s_secret_key_auth_db_username
      k8s_secret_key_auth_db_password      = local.k8s_secret_key_auth_db_password

      k8s_secret_key_jwt_signing_key      = local.k8s_secret_key_jwt_signing_key
      k8s_secret_key_openai_api_key       = local.k8s_secret_key_openai_api_key
      k8s_secret_key_nebuly_client_secret = local.k8s_secret_key_nebuly_client_secret
      k8s_secret_key_nebuly_client_id     = local.k8s_secret_key_nebuly_client_id

      analytics_postgres_server_url = google_sql_database_instance.main.private_ip_address
      analytics_postgres_db_name    = google_sql_database.analytics.name
      auth_postgres_server_url      = google_sql_database_instance.main.private_ip_address
      auth_postgres_db_name         = google_sql_database.auth.name

      gcp_bucket_name  = google_storage_bucket.main.name
      gcp_project_name = data.google_project.current.project_id
    },
  )
  secret_provider_class = templatefile(
    "${path.module}/templates/secret-provider-class.tpl.yaml",
    {
      secret_provider_class_name        = local.secret_provider_class_name
      secret_provider_class_secret_name = local.secret_provider_class_secret_name

      secret_name_jwt_signing_key       = google_secret_manager_secret_version.jwt_signing_key.name
      secret_name_auth_db_username      = google_secret_manager_secret_version.postgres_auth_username.name
      secret_name_auth_db_password      = google_secret_manager_secret_version.postgres_auth_password.name
      secret_name_analytics_db_username = google_secret_manager_secret_version.postgres_analytics_username.name
      secret_name_analytics_db_password = google_secret_manager_secret_version.postgres_analytics_password.name
      secret_name_openai_api_key        = google_secret_manager_secret_version.openai_api_key.name

      secret_name_nebuly_client_id     = google_secret_manager_secret_version.nebuly_client_id.name
      secret_name_nebuly_client_secret = google_secret_manager_secret_version.nebuly_client_secret.name

      k8s_secret_key_auth_db_username      = local.k8s_secret_key_auth_db_username
      k8s_secret_key_auth_db_password      = local.k8s_secret_key_auth_db_password
      k8s_secret_key_analytics_db_username = local.k8s_secret_key_analytics_db_username
      k8s_secret_key_analytics_db_password = local.k8s_secret_key_analytics_db_password
      k8s_secret_key_jwt_signing_key       = local.k8s_secret_key_jwt_signing_key
      k8s_secret_key_openai_api_key        = local.k8s_secret_key_openai_api_key
      k8s_secret_key_nebuly_client_secret  = local.k8s_secret_key_nebuly_client_secret
      k8s_secret_key_nebuly_client_id      = local.k8s_secret_key_nebuly_client_id
    },
  )
}

