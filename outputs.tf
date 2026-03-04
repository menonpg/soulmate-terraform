output "api_url" {
  description = "SoulMate API endpoint URL"
  value       = google_cloud_run_v2_service.soulmate.uri
}

output "memory_bucket" {
  description = "Cloud Storage bucket for memory files"
  value       = google_storage_bucket.memory.name
}

output "db_instance" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.soulmate.connection_name
}

output "service_account" {
  description = "SoulMate API service account email"
  value       = google_service_account.soulmate.email
}

output "monitoring_url" {
  description = "Cloud Monitoring dashboard URL"
  value       = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}"
}

output "logs_url" {
  description = "Cloud Logging URL for audit trail"
  value       = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
}
