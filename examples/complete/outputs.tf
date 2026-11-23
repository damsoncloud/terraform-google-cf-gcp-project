output "project_ids" {
  description = "IDs of the workload projects, by name."
  value       = { for name, project in module.gcp_project : name => project.project_id }
}

output "perimeter_members" {
  description = "Names of the workload projects added to the perimeter."
  value       = [for name, project in module.gcp_project : name if project.perimeter_member]
}
