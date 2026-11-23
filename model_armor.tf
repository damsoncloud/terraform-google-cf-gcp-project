resource "google_project_service" "model_armor" {
  count = var.model_armor == null ? 0 : 1

  project            = google_project.project.project_id
  service            = "modelarmor.googleapis.com"
  disable_on_destroy = false
}

# The Agent Platform and Google MCP server integrations can only be set on projects. The project's filters replace the organisation's floor setting's, so they
# repeat them (cf-organization's `model_armor` output).
resource "google_model_armor_floorsetting" "project" {
  count = var.model_armor == null ? 0 : 1

  parent                           = "projects/${google_project_service.model_armor[0].project}"
  location                         = "global"
  enable_floor_setting_enforcement = var.model_armor.enforcement
  integrated_services              = keys(var.model_armor.integrated_services)

  filter_config {
    dynamic "rai_settings" {
      for_each = length(var.model_armor.responsible_ai_filters) > 0 ? [var.model_armor.responsible_ai_filters] : []

      content {
        dynamic "rai_filters" {
          for_each = rai_settings.value

          content {
            filter_type      = rai_filters.value
            confidence_level = var.model_armor.confidence_level
          }
        }
      }
    }

    pi_and_jailbreak_filter_settings {
      filter_enforcement = var.model_armor.prompt_injection_and_jailbreak ? "ENABLED" : "DISABLED"
      confidence_level   = var.model_armor.confidence_level
    }

    malicious_uri_filter_settings {
      filter_enforcement = var.model_armor.malicious_uri ? "ENABLED" : "DISABLED"
    }

    sdp_settings {
      basic_config {
        filter_enforcement = var.model_armor.sensitive_data_protection ? "ENABLED" : "DISABLED"
      }
    }
  }

  # Only the selected mode is set, as the provider refuses both, even when false
  dynamic "ai_platform_floor_setting" {
    for_each = contains(keys(var.model_armor.integrated_services), "AI_PLATFORM") ? [var.model_armor.integrated_services["AI_PLATFORM"]] : []

    content {
      inspect_and_block    = ai_platform_floor_setting.value == "INSPECT_AND_BLOCK" ? true : null
      inspect_only         = ai_platform_floor_setting.value == "INSPECT_ONLY" ? true : null
      enable_cloud_logging = var.model_armor.cloud_logging
    }
  }

  dynamic "google_mcp_server_floor_setting" {
    for_each = contains(keys(var.model_armor.integrated_services), "GOOGLE_MCP_SERVER") ? [var.model_armor.integrated_services["GOOGLE_MCP_SERVER"]] : []

    content {
      inspect_and_block    = google_mcp_server_floor_setting.value == "INSPECT_AND_BLOCK" ? true : null
      inspect_only         = google_mcp_server_floor_setting.value == "INSPECT_ONLY" ? true : null
      enable_cloud_logging = var.model_armor.cloud_logging
    }
  }

  floor_setting_metadata {
    multi_language_detection {
      enable_multi_language_detection = var.model_armor.multi_language_detection
    }
  }
}
