run "setup" {
  module {
    source = "./tests/setup"
  }

  # Setup only reads credentials from disk; do not inherit the Google provider
  # whose config depends on this run's output (cycle on Terraform >= 1.10).
  providers = {}
}

provider "google" {
  region      = var.region
  project     = var.project
  credentials = run.setup.credentials
}

run "smoke_test_plan" {
  command = plan

  variables {
    platform_domain = "test.nebuly.com"

    openai_api_key  = "test"
    openai_endpoint = "https://test.nebuly.com"

    gke_cluster_admin_users = []

    nebuly_credentials = {
      client_id     = "test"
      client_secret = "test"
    }
  }
}
