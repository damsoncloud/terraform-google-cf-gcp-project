variable "folders" {
  description = "The folders by folder name, e.g. the `folders` output of cf-hierarchy: `id`, the resource name (`folders/<id>`); `short_name`, the environment's short name, null for folders other than environments; `common`, whether it is the common environment."
  type = map(object({
    id         = string
    short_name = optional(string)
    common     = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for folder in values(var.folders) : can(regex("^folders/[0-9]+$", folder.id))])
    error_message = "Each folder's id must be `folders/<id>`."
  }
}

variable "environment" {
  description = "Name of the environment folder of the project, a key of `folders` with a short name, e.g. `production`. The short name prefixes the generated project ID and is the project's `environment` label."
  type        = string

  validation {
    condition     = try(var.folders[var.environment].short_name != null, false)
    error_message = "The environment must be a folder of `folders` with a short name."
  }
}

variable "name" {
  description = "Name of the project, generating its ID `<environment short name>-<name>-<suffix>` with a random 4 hexadecimal characters suffix, e.g. `prod-backend-a1b2`."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.name))
    error_message = "The name must be lowercase letters, digits or hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "project_id" {
  description = "ID of the project, replacing the generated one, e.g. to follow another naming pattern or to keep the ID of an existing project."
  type        = string
  default     = null

  validation {
    condition     = var.project_id == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id must be 6-30 lowercase letters, digits or hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "display_name" {
  description = "Display name of the project; its ID when null."
  type        = string
  default     = null
}

variable "billing_account" {
  description = "ID of the billing account of the project and its budget, e.g. `012345-6789AB-CDEF01`."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "The billing_account must be a billing account ID, e.g. `012345-6789AB-CDEF01`."
  }
}

variable "observability_project_id" {
  description = "ID of the Observability project, e.g. the `observability_project_id` output of cf-organization, whose metrics scope the project is added to."
  type        = string
}

variable "services" {
  description = "APIs enabled in the project, e.g. `run.googleapis.com`. They are left enabled when removed from the list."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "labels" {
  description = "Labels of the project, following the labelling strategy of the customer design document: at least `component`, `department` and `owner`, e.g. a team name or an email with `_at_` and `_` in place of `@` and dots. The `environment` label is set to the environment's short name."
  type        = map(string)

  validation {
    condition     = alltrue([for label in ["component", "department", "owner"] : contains(keys(var.labels), label)])
    error_message = "The labels must include component, department and owner."
  }

  validation {
    condition = alltrue([for key, value in var.labels :
      can(regex("^[\\p{Ll}\\p{Lo}][\\p{Ll}\\p{Lo}\\p{N}_-]{0,62}$", key)) && can(regex("^[\\p{Ll}\\p{Lo}\\p{N}_-]{0,63}$", value))
    ])
    error_message = "Label keys must be 1-63 and values 0-63 lowercase letters, digits, underscores or hyphens, keys starting with a letter, e.g. `team_at_example_com` for an email."
  }
}

variable "deletion_policy" {
  description = "Whether Terraform can delete the project: `PREVENT`, `ABANDON` (removed from the state only) or `DELETE`."
  type        = string
  default     = "PREVENT"
  nullable    = false

  validation {
    condition     = contains(["PREVENT", "ABANDON", "DELETE"], var.deletion_policy)
    error_message = "The deletion_policy must be PREVENT, ABANDON or DELETE."
  }
}

variable "essential_contacts" {
  description = "Essential contacts of the project, in addition to those inherited from the organisation and its folder: the notification categories by email, e.g. `{ \"team@example.com\" = [\"TECHNICAL\", \"SECURITY\"] }`."
  type        = map(list(string))
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([for categories in values(var.essential_contacts) : length(categories) > 0 && length(setsubtract(categories, [
      "ALL", "BILLING", "LEGAL", "PRODUCT_UPDATES", "SECURITY", "SUSPENSION", "TECHNICAL", "TECHNICAL_INCIDENTS",
    ])) == 0])
    error_message = "Each essential contact needs at least one category of ALL, BILLING, LEGAL, PRODUCT_UPDATES, SECURITY, SUSPENSION, TECHNICAL or TECHNICAL_INCIDENTS."
  }
}

variable "essential_contacts_language" {
  description = "Language of the essential contacts' notifications, as a BCP-47 tag."
  type        = string
  default     = "en-GB"
  nullable    = false
}

variable "billing_notification_channel" {
  description = "ID of the notification channel of the billing administrators, notified of the budget's alerts, e.g. the `billing_notification_channel` output of cf-organization."
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/notificationChannels/[0-9]+$", var.billing_notification_channel))
    error_message = "The billing_notification_channel must be `projects/<project>/notificationChannels/<id>`."
  }
}

variable "budget" {
  description = "The project's budget: `amount`, in the billing account's currency; `thresholds`, the fractions of the amount alerting the billing administrators."
  type = object({
    amount     = optional(number, 100)
    thresholds = optional(list(number), [0.5, 0.7, 1.0])
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.budget.amount > 0 && floor(var.budget.amount) == var.budget.amount
    error_message = "The budget amount must be a positive whole number."
  }

  validation {
    condition     = length(var.budget.thresholds) > 0 && alltrue([for threshold in var.budget.thresholds : threshold > 0])
    error_message = "The budget needs at least one threshold, each greater than 0."
  }
}

variable "billing_disabler" {
  description = <<-EOT
  The billing disabler, disabling the project's billing when its budget is exceeded; not enabled when null:
    `topic`, the topic of its budget notifications, e.g. the `billing_disabler_topic` output of cf-observability;
    `email`, its service account, e.g. the `billing_disabler_email` output of cf-organization;
    `project_roles`, the service account's roles on the project, e.g. the `billing_disabler_project_roles` output of cf-organization.
  EOT
  type = object({
    topic         = string
    email         = string
    project_roles = list(string)
  })
  default = null

  validation {
    condition     = var.billing_disabler == null || can(regex("^projects/[^/]+/topics/[^/]+$", var.billing_disabler.topic))
    error_message = "The billing_disabler topic must be `projects/<project>/topics/<name>`."
  }
}

variable "vpc_service_controls" {
  description = <<-EOT
  The VPC Service Controls perimeter of the production and common environments, e.g. of cf-organization's vpc-service-controls submodule; not used when null:
    `perimeter_name`, the perimeter's resource name, e.g. the submodule's `perimeter_name` output;
    `mode`, the submodule's mode: the ingress rules are added to the dry-run configuration, and to the enforced one too when `enforced`;
    `environments`, the folder names of the environments in the perimeter, to whose configurations the project is added when it is in one of them;
    `ingress_rules`, the project's ingress rules, e.g. of its integrations, by title, added when the project is in the perimeter:
      `identities` or `identity_type` (`ANY_IDENTITY`, `ANY_USER_ACCOUNT` or `ANY_SERVICE_ACCOUNT`), the principals allowed;
      `source_access_levels`, the names of the access policy's access levels or `*` for any source, and `source_resources`, e.g. `projects/<number>`;
      `operations`, the methods by service into the project, `*` for all services, and all methods of a service when its list is empty.
  EOT
  type = object({
    perimeter_name = string
    mode           = optional(string, "dry_run")
    environments   = optional(list(string), ["production", "common"])
    ingress_rules = optional(map(object({
      identities           = optional(list(string), [])
      identity_type        = optional(string)
      source_access_levels = optional(list(string), ["*"])
      source_resources     = optional(list(string), [])
      operations           = optional(map(list(string)), { "*" = [] })
    })), {})
  })
  default = null

  validation {
    condition     = var.vpc_service_controls == null || can(regex("^accessPolicies/[0-9]+/servicePerimeters/[A-Za-z0-9_]+$", var.vpc_service_controls.perimeter_name))
    error_message = "The perimeter_name must be `accessPolicies/<id>/servicePerimeters/<name>`."
  }

  validation {
    condition     = var.vpc_service_controls == null || contains(["dry_run", "enforced"], try(var.vpc_service_controls.mode, ""))
    error_message = "The mode must be dry_run or enforced."
  }

  validation {
    condition     = var.vpc_service_controls == null || try(length(setsubtract(var.vpc_service_controls.environments, keys(var.folders))) == 0, false)
    error_message = "The perimeter's environments must be folders of `folders`."
  }

  validation {
    condition = var.vpc_service_controls == null || try(alltrue([for rule in values(var.vpc_service_controls.ingress_rules) :
      (length(rule.identities) > 0) != (rule.identity_type != null) &&
      (rule.identity_type == null || contains(["ANY_IDENTITY", "ANY_USER_ACCOUNT", "ANY_SERVICE_ACCOUNT"], rule.identity_type)) &&
      length(rule.source_access_levels) + length(rule.source_resources) > 0 &&
      length(rule.operations) > 0
    ]), false)
    error_message = "Each ingress rule needs either identities or an identity_type (ANY_IDENTITY, ANY_USER_ACCOUNT or ANY_SERVICE_ACCOUNT), at least one source and at least one operation."
  }
}

variable "model_armor" {
  description = <<-EOT
    The project's Model Armour floor setting, screening the integrated services' traffic and replacing the organisation's floor setting's filters, which it should repeat,
    e.g. with the `model_armor` output of cf-organization; neither set nor the Model Armor API enabled when null:
    `enforcement`, whether the floor setting is enforced, without which it screens nothing;
    `integrated_services`, the screening mode, `INSPECT_AND_BLOCK` or `INSPECT_ONLY`, by integrated service: `AI_PLATFORM` (Agent Platform) and `GOOGLE_MCP_SERVER`;
    `cloud_logging`, whether the screening results are logged;
    `confidence_level`, the confidence level of the Responsible AI and the prompt injection and jailbreak filters: `LOW_AND_ABOVE`, `MEDIUM_AND_ABOVE` or `HIGH`;
    `responsible_ai_filters`, the Responsible AI filters: `SEXUALLY_EXPLICIT`, `HATE_SPEECH`, `HARASSMENT` or `DANGEROUS`;
    `prompt_injection_and_jailbreak`, `malicious_uri` and `sensitive_data_protection` (basic configuration), whether these filters are enabled;
    `multi_language_detection`, whether prompts and responses are screened in all supported languages.
  EOT
  type = object({
    enforcement                    = optional(bool, true)
    integrated_services            = optional(map(string), { AI_PLATFORM = "INSPECT_AND_BLOCK", GOOGLE_MCP_SERVER = "INSPECT_AND_BLOCK" })
    cloud_logging                  = optional(bool, false)
    confidence_level               = optional(string, "MEDIUM_AND_ABOVE")
    responsible_ai_filters         = optional(list(string), ["DANGEROUS", "HARASSMENT", "HATE_SPEECH", "SEXUALLY_EXPLICIT"])
    prompt_injection_and_jailbreak = optional(bool, true)
    malicious_uri                  = optional(bool, true)
    sensitive_data_protection      = optional(bool, true)
    multi_language_detection       = optional(bool, true)
  })
  default = {}

  validation {
    condition = var.model_armor == null || try(
      length(var.model_armor.integrated_services) > 0 &&
      length(setsubtract(keys(var.model_armor.integrated_services), ["AI_PLATFORM", "GOOGLE_MCP_SERVER"])) == 0 &&
      length(setsubtract(values(var.model_armor.integrated_services), ["INSPECT_AND_BLOCK", "INSPECT_ONLY"])) == 0,
      false
    )
    error_message = "The model_armor integrated_services must map AI_PLATFORM or GOOGLE_MCP_SERVER, at least one, to INSPECT_AND_BLOCK or INSPECT_ONLY."
  }

  validation {
    condition     = var.model_armor == null || contains(["LOW_AND_ABOVE", "MEDIUM_AND_ABOVE", "HIGH"], try(var.model_armor.confidence_level, ""))
    error_message = "The model_armor confidence_level must be LOW_AND_ABOVE, MEDIUM_AND_ABOVE or HIGH."
  }

  validation {
    condition     = var.model_armor == null || try(alltrue([for filter in var.model_armor.responsible_ai_filters : contains(["SEXUALLY_EXPLICIT", "HATE_SPEECH", "HARASSMENT", "DANGEROUS"], filter)]), false)
    error_message = "Each model_armor Responsible AI filter must be SEXUALLY_EXPLICIT, HATE_SPEECH, HARASSMENT or DANGEROUS."
  }
}
