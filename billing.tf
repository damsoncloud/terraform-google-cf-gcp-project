resource "google_billing_budget" "project" {
  billing_account = var.billing_account
  display_name    = google_project.project.project_id

  budget_filter {
    projects = ["projects/${google_project.project.number}"]
  }

  # Without a currency code, the amount is in the billing account's currency
  amount {
    specified_amount {
      units = tostring(var.budget.amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget.thresholds

    content {
      threshold_percent = threshold_rules.value
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [var.billing_notification_channel]
    pubsub_topic                     = try(var.billing_disabler.topic, null)
    schema_version                   = var.billing_disabler == null ? null : "1.0"
  }
}

# Reads the project and detaches it from its billing account; the organisation role is granted by cf-organization
resource "google_project_iam_member" "billing_disabler" {
  for_each = toset(try(var.billing_disabler.project_roles, []))

  project = google_project.project.project_id
  role    = each.key
  member  = "serviceAccount:${var.billing_disabler.email}"
}
