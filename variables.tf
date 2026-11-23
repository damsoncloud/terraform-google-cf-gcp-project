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
