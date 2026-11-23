output "project_id" {
  description = "ID of the project."
  value       = google_project.project.project_id
}

output "project_number" {
  description = "Number of the project."
  value       = google_project.project.number
}
