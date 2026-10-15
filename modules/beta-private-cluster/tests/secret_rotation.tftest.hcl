mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "kubernetes" {}
mock_provider "random" {}

variables {
  project_id                  = "fixture-project"
  name                        = "fixture-cluster"
  region                      = "us-central1"
  zones                       = ["us-central1-a"]
  network                     = "fixture-network"
  subnetwork                  = "fixture-subnetwork"
  ip_range_pods               = "fixture-pods"
  ip_range_services           = "fixture-services"
  kubernetes_version          = "1.35.8-gke.1439001"
  create_service_account      = false
  service_account             = "fixture@fixture-project.iam.gserviceaccount.com"
  enable_secret_manager_addon = true
}

run "existing_callers_omit_rotation_configuration" {
  command = plan

  plan_options {
    target = [google_container_cluster.primary]
  }

  assert {
    condition     = length(google_container_cluster.primary.secret_manager_config[0].rotation_config) == 0
    error_message = "Existing module callers must not acquire a rotation policy implicitly."
  }
}

run "mounted_secrets_refresh_every_two_minutes" {
  command = plan

  variables {
    secret_manager_rotation_config = { enabled = true, rotation_interval = "120s" }
  }

  plan_options {
    target = [google_container_cluster.primary]
  }

  assert {
    condition = (
      google_container_cluster.primary.secret_manager_config[0].enabled &&
      google_container_cluster.primary.secret_manager_config[0].rotation_config[0].enabled &&
      google_container_cluster.primary.secret_manager_config[0].rotation_config[0].rotation_interval == "120s"
    )
    error_message = "The native Secret Manager rotation policy must be enabled at 120s."
  }
}

run "rotation_can_be_explicitly_disabled" {
  command = plan

  variables {
    secret_manager_rotation_config = { enabled = false }
  }

  plan_options {
    target = [google_container_cluster.primary]
  }

  assert {
    condition     = !google_container_cluster.primary.secret_manager_config[0].rotation_config[0].enabled
    error_message = "Disabling rotation must be an explicit managed configuration, not an omitted computed field."
  }
}

run "reject_intervals_below_the_gke_minimum" {
  command = plan

  variables {
    secret_manager_rotation_config = { enabled = true, rotation_interval = "59s" }
  }

  expect_failures = [var.secret_manager_rotation_config]
}

run "reject_non_second_durations" {
  command = plan

  variables {
    secret_manager_rotation_config = { enabled = true, rotation_interval = "2m" }
  }

  expect_failures = [var.secret_manager_rotation_config]
}
