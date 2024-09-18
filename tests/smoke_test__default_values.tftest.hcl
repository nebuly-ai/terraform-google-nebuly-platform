run "setup" {
  module {
    source = "./tests/setup"
  }
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
    openai_gpt4_deployment_name = "test"

    gke_cluster_admin_users = []

    nebuly_credentials = {
      client_id     = "test"
      client_secret = "test"
    }
  }
}
