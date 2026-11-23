variable "organization_id" {
  description = "ID of the organisation."
  type        = string
}

variable "domain" {
  description = "Domain of the organisation's groups."
  type        = string
}

variable "billing_account" {
  description = "ID of the billing account."
  type        = string
}

variable "mode" {
  description = "Mode of the perimeter, including the ingress rules of cf-observability and of the projects: `dry_run` first, then `enforced`."
  type        = string
  default     = "dry_run"
}

variable "partner_service_account" {
  description = "Email of the partner's service account uploading into the backend project."
  type        = string
}

variable "partner_ip_ranges" {
  description = "IP ranges of the partner's network, in CIDR notation."
  type        = list(string)
}
