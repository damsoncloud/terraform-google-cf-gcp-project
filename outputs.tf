output "project_id" {
  description = "ID of the project."
  value       = google_project.project.project_id
}

output "project_number" {
  description = "Number of the project."
  value       = google_project.project.number
}

output "budget" {
  description = "Resource name of the project's budget (`billingAccounts/<id>/budgets/<id>`)."
  value       = google_billing_budget.project.name
}

output "perimeter_member" {
  description = "Whether the project was added to the VPC Service Controls perimeter."
  value       = local.perimeter_member
}

output "shared_vpc_host_project_id" {
  description = "ID of the Shared VPC host project the project is attached to; null when not attached."
  value       = one(google_compute_shared_vpc_service_project.project[*].host_project)
}
