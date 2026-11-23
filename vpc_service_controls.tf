locals {
  perimeter_member   = var.vpc_service_controls != null && contains(try(var.vpc_service_controls.environments, []), var.environment)
  perimeter_enforced = local.perimeter_member && try(var.vpc_service_controls.mode, null) == "enforced"
  access_policy      = try(regex("^accessPolicies/[0-9]+", var.vpc_service_controls.perimeter_name), null)

  # Titles are unique in the perimeter, which holds the rules of every module and project
  perimeter_ingress_rules = !local.perimeter_member ? {} : {
    for title, rule in var.vpc_service_controls.ingress_rules : "${local.project_id}: ${title}" => merge(rule, {
      source_access_levels = [for level in rule.source_access_levels : level == "*" ? level : "${local.access_policy}/accessLevels/${level}"]
    })
  }
}

# The project is added to both configurations, as by the vpc-service-controls submodule, so that switching the mode does not change the membership
resource "google_access_context_manager_service_perimeter_resource" "project" {
  count = local.perimeter_member ? 1 : 0

  perimeter_name = var.vpc_service_controls.perimeter_name
  resource       = "projects/${google_project.project.number}"
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "project" {
  count = local.perimeter_member ? 1 : 0

  perimeter_name = var.vpc_service_controls.perimeter_name
  resource       = "projects/${google_project.project.number}"
}

# Rules are added to the enforced configuration only when enforced, and always to the dry-run configuration
resource "google_access_context_manager_service_perimeter_ingress_policy" "rules" {
  for_each = local.perimeter_enforced ? local.perimeter_ingress_rules : {}

  perimeter = var.vpc_service_controls.perimeter_name
  title     = each.key

  ingress_from {
    identities    = length(each.value.identities) > 0 ? each.value.identities : null
    identity_type = each.value.identity_type

    dynamic "sources" {
      for_each = each.value.source_access_levels

      content {
        access_level = sources.value
      }
    }

    dynamic "sources" {
      for_each = each.value.source_resources

      content {
        resource = sources.value
      }
    }
  }

  ingress_to {
    resources = ["projects/${google_project.project.number}"]

    dynamic "operations" {
      for_each = each.value.operations

      content {
        service_name = operations.key

        dynamic "method_selectors" {
          for_each = operations.key == "*" ? [] : (length(operations.value) > 0 ? operations.value : ["*"])

          content {
            method = method_selectors.value
          }
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_access_context_manager_service_perimeter_resource.project]
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "rules" {
  for_each = local.perimeter_ingress_rules

  perimeter = var.vpc_service_controls.perimeter_name
  title     = each.key

  ingress_from {
    identities    = length(each.value.identities) > 0 ? each.value.identities : null
    identity_type = each.value.identity_type

    dynamic "sources" {
      for_each = each.value.source_access_levels

      content {
        access_level = sources.value
      }
    }

    dynamic "sources" {
      for_each = each.value.source_resources

      content {
        resource = sources.value
      }
    }
  }

  ingress_to {
    resources = ["projects/${google_project.project.number}"]

    dynamic "operations" {
      for_each = each.value.operations

      content {
        service_name = operations.key

        dynamic "method_selectors" {
          for_each = operations.key == "*" ? [] : (length(operations.value) > 0 ? operations.value : ["*"])

          content {
            method = method_selectors.value
          }
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_access_context_manager_service_perimeter_dry_run_resource.project]
}
