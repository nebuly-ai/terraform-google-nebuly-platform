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
    openai_gpt4o_deployment_name = "gpt-4o"
    openai_translation_deployment_name = "gpt-4o-mini"


    # ------ Microsoft SSO ------ #
    microsoft_sso_credentials = {
      tenant_id : "my-tenant-id"
      client_id : "my-client-id"
      client_secret : "my-client-secret"
    }

    gke_cluster_admin_users = []

    nebuly_credentials = {
      client_id     = "test"
      client_secret = "test"
    }
  }
}
