output "project_ids" {
  description = "IDs of the workload projects, by name."
  value       = { for name, project in module.gcp_project : name => project.project_id }
}
