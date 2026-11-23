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
