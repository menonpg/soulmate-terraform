# ── Required ──────────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID to deploy SoulMate into"
  type        = string
}

variable "region" {
  description = "GCP region (e.g. us-central1, us-east1, europe-west1)"
  type        = string
  default     = "us-central1"
}

variable "admin_email" {
  description = "Admin email address — gets IAM owner role and IAP access"
  type        = string
}

# ── Optional ──────────────────────────────────────────────────────────────────

variable "app_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "soulmate"
}

variable "image_tag" {
  description = "SoulMate API Docker image tag"
  type        = string
  default     = "latest"
}

variable "image" {
  description = "Full Docker image path (override to use a custom registry)"
  type        = string
  default     = "pgmenon/soulmate-api"
}

variable "cloud_run_cpu" {
  description = "CPU limit for Cloud Run container"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory limit for Cloud Run container"
  type        = string
  default     = "512Mi"
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "soulmate"
}

variable "enable_iap" {
  description = "Enable Identity-Aware Proxy for Google Workspace SSO"
  type        = bool
  default     = true
}

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor WAF for DDoS protection"
  type        = bool
  default     = false
}

variable "data_retention_days" {
  description = "Number of days to retain audit logs in Cloud Logging"
  type        = number
  default     = 365
}

variable "allowed_domains" {
  description = "List of allowed email domains for IAP access (empty = admin only)"
  type        = list(string)
  default     = []
}
