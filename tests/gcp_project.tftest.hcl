mock_provider "google" {
  mock_resource "google_project" {
    defaults = {
      number = "444444444444"
    }
  }

  mock_resource "google_billing_budget" {
    defaults = {
      name = "billingAccounts/012345-6789AB-CDEF01/budgets/0a1b2c3d-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "e5f6"
    }
  }
}

variables {
  folders = {
    development   = { id = "folders/100000000001", short_name = "dev" }
    certification = { id = "folders/100000000002", short_name = "cert" }
    production    = { id = "folders/100000000003", short_name = "prod" }
    common        = { id = "folders/111111111111", short_name = "cmn", common = true }
    legacy        = { id = "folders/100000000004" }
  }
  environment                  = "production"
  name                         = "backend"
  billing_account              = "012345-6789AB-CDEF01"
  observability_project_id     = "cmn-observability-c3d4"
  billing_notification_channel = "projects/cmn-observability-c3d4/notificationChannels/1234567890"
  labels                       = { component = "backend", department = "engineering", owner = "team-backend" }
}

run "project" {
  variables {
    services = ["run.googleapis.com", "storage.googleapis.com"]
  }

  assert {
    condition = (
      output.project_id == "prod-backend-e5f6" &&
      output.project_number == "444444444444" &&
      google_project.project.name == "prod-backend-e5f6" &&
      google_project.project.folder_id == "folders/100000000003" &&
      google_project.project.billing_account == "012345-6789AB-CDEF01" &&
      google_project.project.auto_create_network == false &&
      google_project.project.deletion_policy == "PREVENT"
    )
    error_message = "The project must be created in its environment's folder with a generated ID, without the default network and protected from deletion."
  }

  assert {
    condition     = google_project.project.labels == tomap({ component = "backend", department = "engineering", owner = "team-backend", environment = "prod" })
    error_message = "The project must be labelled with its environment's short name in addition to the given labels."
  }

  assert {
    condition = (
      toset(keys(google_project_service.services)) == toset(["run.googleapis.com", "storage.googleapis.com"]) &&
      alltrue([for service in google_project_service.services : service.project == "prod-backend-e5f6" && !service.disable_on_destroy])
    )
    error_message = "The given APIs must be enabled in the project."
  }

  assert {
    condition = (
      google_monitoring_monitored_project.project.metrics_scope == "locations/global/metricsScopes/cmn-observability-c3d4" &&
      google_monitoring_monitored_project.project.name == "prod-backend-e5f6"
    )
    error_message = "The project must be added to the Observability project's metrics scope."
  }

  assert {
    condition     = length(google_essential_contacts_contact.contacts) == 0
    error_message = "No essential contact must be created by default."
  }
}

run "custom_project_id" {
  command = plan

  variables {
    environment     = "common"
    project_id      = "dc-common-dcp-backend-1234"
    display_name    = "Backend"
    deletion_policy = "DELETE"
    labels          = { component = "backend", department = "engineering", owner = "jane_doe_at_example_com", environment = "overridden" }
  }

  assert {
    condition = (
      google_project.project.project_id == "dc-common-dcp-backend-1234" &&
      google_project.project.name == "Backend" &&
      google_project.project.folder_id == "folders/111111111111" &&
      google_project.project.deletion_policy == "DELETE" &&
      google_project.project.labels["environment"] == "cmn"
    )
    error_message = "The given project ID, display name and deletion policy must be used, and the environment label must not be overridden."
  }
}

run "essential_contacts" {
  variables {
    essential_contacts = {
      "team-backend@example.com" = ["TECHNICAL", "SECURITY"]
    }
  }

  assert {
    condition = (
      google_essential_contacts_contact.contacts["team-backend@example.com"].parent == "projects/prod-backend-e5f6" &&
      google_essential_contacts_contact.contacts["team-backend@example.com"].language_tag == "en-GB" &&
      toset(google_essential_contacts_contact.contacts["team-backend@example.com"].notification_category_subscriptions) == toset(["TECHNICAL", "SECURITY"])
    )
    error_message = "The essential contacts must be created on the project with their categories."
  }
}

run "budget" {
  assert {
    condition = (
      google_billing_budget.project.billing_account == "012345-6789AB-CDEF01" &&
      google_billing_budget.project.display_name == "prod-backend-e5f6" &&
      google_billing_budget.project.budget_filter[0].projects == toset(["projects/444444444444"]) &&
      google_billing_budget.project.amount[0].specified_amount[0].units == "100" &&
      [for rule in google_billing_budget.project.threshold_rules : rule.threshold_percent] == [0.5, 0.7, 1.0] &&
      google_billing_budget.project.all_updates_rule[0].monitoring_notification_channels == tolist(["projects/cmn-observability-c3d4/notificationChannels/1234567890"]) &&
      google_billing_budget.project.all_updates_rule[0].pubsub_topic == null &&
      output.budget == "billingAccounts/012345-6789AB-CDEF01/budgets/0a1b2c3d-0000-0000-0000-000000000000"
    )
    error_message = "The project must get a budget of 100 with alerts at 50%, 70% and 100% to the billing administrators, not published to a topic by default."
  }

  assert {
    condition     = length(google_project_iam_member.billing_disabler) == 0
    error_message = "The billing disabler must not get any role by default."
  }
}

run "billing_disabler" {
  variables {
    budget = { amount = 250, thresholds = [0.9, 1.0] }
    billing_disabler = {
      topic         = "projects/cmn-observability-c3d4/topics/cmn-cf-billing-disabler"
      email         = "billing-disabler@cmn-observability-c3d4.iam.gserviceaccount.com"
      project_roles = ["roles/billing.projectManager", "roles/browser"]
    }
  }

  assert {
    condition = (
      google_billing_budget.project.amount[0].specified_amount[0].units == "250" &&
      [for rule in google_billing_budget.project.threshold_rules : rule.threshold_percent] == [0.9, 1.0] &&
      google_billing_budget.project.all_updates_rule[0].pubsub_topic == "projects/cmn-observability-c3d4/topics/cmn-cf-billing-disabler" &&
      google_billing_budget.project.all_updates_rule[0].schema_version == "1.0"
    )
    error_message = "The budget must have the given amount and thresholds and publish its notifications to the billing disabler's topic."
  }

  assert {
    condition = (
      toset(keys(google_project_iam_member.billing_disabler)) == toset(["roles/billing.projectManager", "roles/browser"]) &&
      alltrue([for binding in google_project_iam_member.billing_disabler :
        binding.project == "prod-backend-e5f6" && binding.member == "serviceAccount:billing-disabler@cmn-observability-c3d4.iam.gserviceaccount.com"
      ])
    )
    error_message = "The billing disabler's service account must get its project roles."
  }
}

run "invalid_billing" {
  command = plan

  variables {
    billing_notification_channel = "billing-admins"
    budget                       = { amount = 10.5, thresholds = [] }
    billing_disabler             = { topic = "cmn-cf-billing-disabler", email = "billing-disabler@cmn-observability-c3d4.iam.gserviceaccount.com", project_roles = [] }
  }

  expect_failures = [var.billing_notification_channel, var.budget, var.billing_disabler]
}

run "too_long_project_id" {
  command = plan

  variables {
    name = "a-very-long-project-name"
  }

  expect_failures = [google_project.project]
}

run "invalid_inputs" {
  command = plan

  variables {
    environment        = "legacy"
    name               = "Backend"
    project_id         = "x"
    billing_account    = "billing"
    deletion_policy    = "KEEP"
    essential_contacts = { "team@example.com" = ["URGENT"] }
  }

  expect_failures = [
    var.environment,
    var.name,
    var.project_id,
    var.billing_account,
    var.deletion_policy,
    var.essential_contacts,
  ]
}

run "missing_labels" {
  command = plan

  variables {
    labels = { component = "backend" }
  }

  expect_failures = [var.labels]
}

run "invalid_labels" {
  command = plan

  variables {
    labels = { component = "backend", department = "engineering", owner = "jane.doe@example.com" }
  }

  expect_failures = [var.labels]
}
