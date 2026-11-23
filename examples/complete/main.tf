module "hierarchy" {
  source  = "damsoncloud/cf-hierarchy/google"
  version = "0.2.0"

  organization_id = var.organization_id
}

module "bootstrap" {
  source  = "damsoncloud/cf-bootstrap/google"
  version = "0.7.0"

  organization_id = var.organization_id
  folders         = module.hierarchy.folders
  billing_account = var.billing_account
}

module "organization" {
  source  = "damsoncloud/cf-organization/google"
  version = "0.3.0"

  organization_id     = var.organization_id
  domain              = var.domain
  environment_tag_key = module.hierarchy.environment_tag_key_namespaced_name
  folders             = module.hierarchy.folders
  billing_account     = var.billing_account

  bootstrap_project_id            = module.bootstrap.project_id
  tf_bootstrap_email              = module.bootstrap.tf_bootstrap_email
  tf_bootstrap_organization_roles = module.bootstrap.tf_bootstrap_organization_roles
  tf_plan_email                   = module.bootstrap.tf_plan_email
  tf_plan_organization_roles      = module.bootstrap.tf_plan_organization_roles
  tf_environment_emails           = module.bootstrap.tf_environment_emails
}

module "vpc_service_controls" {
  source  = "damsoncloud/cf-organization/google//modules/vpc-service-controls"
  version = "0.3.0"

  organization_id = var.organization_id
  mode            = var.mode
  projects = {
    bootstrap      = module.bootstrap.project_number
    observability  = module.organization.observability_project_number
    api_management = module.organization.api_management_project_number
  }
  deployers = concat(
    [module.bootstrap.tf_bootstrap_email, module.bootstrap.tf_plan_email],
    values(module.bootstrap.tf_environment_emails),
  )
  groups = module.organization.perimeter_groups
  access_levels = {
    partner_network = { ip_subnetworks = var.partner_ip_ranges }
  }
}

module "observability" {
  source  = "damsoncloud/cf-observability/google"
  version = "0.1.1"

  organization_id          = var.organization_id
  domain                   = var.domain
  folders                  = module.hierarchy.folders
  observability_project_id = module.organization.observability_project_id
  tf_bootstrap_email       = module.bootstrap.tf_bootstrap_email

  billing_disabler_email       = module.organization.billing_disabler_email
  billing_notification_channel = module.organization.billing_notification_channel

  vpc_service_controls = {
    perimeter_name = module.vpc_service_controls.perimeter_name
    mode           = var.mode
  }
}

# The workload projects, by name
locals {
  projects = {
    backend = {
      environment      = "production"
      services         = ["run.googleapis.com", "sqladmin.googleapis.com", "storage.googleapis.com"]
      labels           = { component = "backend", department = "engineering", owner = "team-backend" }
      budget           = { amount = 500 }
      billing_disabler = false
      contacts         = { "team-backend@example.com" = ["TECHNICAL", "SECURITY"] }
      # The partner's uploads into the project's buckets, from its network only
      ingress_rules = {
        "Partner uploads" = {
          identities           = ["serviceAccount:${var.partner_service_account}"]
          source_access_levels = ["partner_network"]
          operations           = { "storage.googleapis.com" = ["google.storage.objects.create"] }
        }
      }
    }
    sandbox = {
      environment      = "development"
      services         = ["aiplatform.googleapis.com"]
      labels           = { component = "sandbox", department = "engineering", owner = "jane_doe_at_example_com" }
      budget           = { amount = 20, thresholds = [0.5, 0.9, 1.0] }
      billing_disabler = true
      contacts         = {}
      ingress_rules    = {}
    }
  }

  billing_disabler = {
    topic         = module.observability.billing_disabler_topic
    email         = module.organization.billing_disabler_email
    project_roles = module.organization.billing_disabler_project_roles
  }
}

module "gcp_project" {
  source   = "../.."
  for_each = local.projects

  folders                      = module.hierarchy.folders
  environment                  = each.value.environment
  name                         = each.key
  billing_account              = var.billing_account
  observability_project_id     = module.organization.observability_project_id
  billing_notification_channel = module.organization.billing_notification_channel

  services           = each.value.services
  labels             = each.value.labels
  essential_contacts = each.value.contacts
  budget             = each.value.budget
  billing_disabler   = each.value.billing_disabler ? local.billing_disabler : null

  # The organisation's filters, with the screening results logged
  model_armor = merge(module.organization.model_armor, { cloud_logging = true })

  vpc_service_controls = {
    perimeter_name = module.vpc_service_controls.perimeter_name
    mode           = var.mode
    ingress_rules  = each.value.ingress_rules
  }
}
