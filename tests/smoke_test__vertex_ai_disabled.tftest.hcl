run "setup" {
  module {
    source = "./tests/setup"
  }

  providers = {}
}

provider "google" {
  region      = var.region
  project     = var.project
  credentials = run.setup.credentials
}

run "smoke_test_plan_vertex_disabled" {
  command = plan

  variables {
    platform_domain = "test.nebuly.com"

    openai_api_key  = "test"
    openai_endpoint = "https://test.nebuly.com"

    gke_cluster_admin_users = []

    vertex_ai = {
      enabled = false
    }

    nebuly_credentials = {
      client_id     = "test"
      client_secret = "test"
    }
  }
}
