locals {
  short_name = var.folders[var.environment].short_name
  project_id = coalesce(var.project_id, "${local.short_name}-${var.name}-${random_id.suffix.hex}")

  # A Shared VPC service project needs the Compute Engine API
  services = toset(concat(var.services, local.shared_vpc_network == null ? [] : ["compute.googleapis.com"]))
}

# Makes the globally unique generated project ID unique
resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_project" "project" {
  name                = coalesce(var.display_name, local.project_id)
  project_id          = local.project_id
  folder_id           = var.folders[var.environment].id
  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = var.deletion_policy
  labels              = merge(var.labels, { environment = local.short_name })

  lifecycle {
    precondition {
      condition     = length(local.project_id) <= 30
      error_message = "The generated project ID ${local.project_id} is longer than 30 characters: shorten the name or set project_id."
    }
  }
}

resource "google_project_service" "services" {
  for_each = local.services

  project            = google_project.project.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_essential_contacts_contact" "contacts" {
  for_each = var.essential_contacts

  parent                              = "projects/${google_project.project.project_id}"
  email                               = each.key
  language_tag                        = var.essential_contacts_language
  notification_category_subscriptions = each.value
}

# The project's metrics are viewed and alerted on in the Observability project
resource "google_monitoring_monitored_project" "project" {
  metrics_scope = "locations/global/metricsScopes/${var.observability_project_id}"
  name          = google_project.project.project_id
}
