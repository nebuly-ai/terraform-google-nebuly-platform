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

    openai_api_key              = "test"
    openai_endpoint             = "https://test.nebuly.com"
    openai_gpt4o_deployment_name       = "gpt-4o"
    openai_gpt5_deployment_name        = "gpt-5"
    openai_translation_deployment_name = "gpt-4o-mini"

    gke_cluster_admin_users = []

    nebuly_credentials = {
      client_id     = "test"
      client_secret = "test"
    }
  }
}
