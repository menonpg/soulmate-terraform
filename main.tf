# ── SoulMate GCP Deployment ───────────────────────────────────────────────────
# Deploys SoulMate API to Google Cloud Run with:
#   - Cloud SQL (PostgreSQL) for accounts + usage tracking
#   - Cloud Storage for memory files
#   - Secret Manager for API keys
#   - IAP for Google Workspace SSO
#   - Cloud Logging for full audit trail
#
# Usage:
#   terraform init
#   terraform apply \
#     -var="project_id=your-gcp-project" \
#     -var="region=us-central1" \
#     -var="admin_email=you@yourdomain.com"

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Enable required APIs ──────────────────────────────────────────────────────

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# ── Service Account ───────────────────────────────────────────────────────────

resource "google_service_account" "soulmate" {
  account_id   = "${var.app_name}-api"
  display_name = "SoulMate API Service Account"
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "soulmate_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.soulmate.email}"
}

resource "google_project_iam_member" "soulmate_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.soulmate.email}"
}

resource "google_project_iam_member" "soulmate_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.soulmate.email}"
}

resource "google_project_iam_member" "soulmate_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.soulmate.email}"
}

# ── Cloud Storage (memory files) ──────────────────────────────────────────────

resource "google_storage_bucket" "memory" {
  name          = "${var.project_id}-${var.app_name}-memory"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition { num_newer_versions = 10 }
  }
}

# ── Cloud SQL (PostgreSQL) ────────────────────────────────────────────────────

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "soulmate" {
  name             = "${var.app_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region
  depends_on       = [google_project_service.apis]

  settings {
    tier = var.db_tier

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    ip_configuration {
      ipv4_enabled = false
      # Cloud Run connects via Unix socket — no public IP needed
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }
  }

  deletion_protection = true
}

resource "google_sql_database" "soulmate" {
  name     = var.db_name
  instance = google_sql_database_instance.soulmate.name
}

resource "google_sql_user" "soulmate" {
  name     = "soulmate"
  instance = google_sql_database_instance.soulmate.name
  password = random_password.db_password.result
}

# ── Secret Manager ────────────────────────────────────────────────────────────

resource "google_secret_manager_secret" "db_password" {
  secret_id  = "${var.app_name}-db-password"
  depends_on = [google_project_service.apis]
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "api_secret" {
  secret_id  = "${var.app_name}-api-secret"
  depends_on = [google_project_service.apis]
  replication {
    auto {}
  }
}

resource "random_password" "api_secret" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret_version" "api_secret" {
  secret      = google_secret_manager_secret.api_secret.id
  secret_data = random_password.api_secret.result
}

# ── Cloud Run ─────────────────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "soulmate" {
  name     = var.app_name
  location = var.region
  ingress  = var.enable_iap ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"

  depends_on = [
    google_project_service.apis,
    google_sql_database_instance.soulmate,
  ]

  template {
    service_account = google_service_account.soulmate.email

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.soulmate.connection_name]
      }
    }

    containers {
      image = "${var.image}:${var.image_tag}"

      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }
      }

      env {
        name  = "GCP_PROJECT"
        value = var.project_id
      }
      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.memory.name
      }
      env {
        name  = "DB_INSTANCE"
        value = google_sql_database_instance.soulmate.connection_name
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "DB_USER"
        value = "soulmate"
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      liveness_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }
  }
}

# ── IAP (Google Workspace SSO) ────────────────────────────────────────────────

resource "google_iap_web_iam_member" "admin" {
  count   = var.enable_iap ? 1 : 0
  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = "user:${var.admin_email}"
}

resource "google_iap_web_iam_member" "domains" {
  count   = var.enable_iap ? length(var.allowed_domains) : 0
  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = "domain:${var.allowed_domains[count.index]}"
}

# ── Cloud Logging audit sink ──────────────────────────────────────────────────

resource "google_logging_project_sink" "soulmate_audit" {
  name        = "${var.app_name}-audit"
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/_Default"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.app_name}\""

  unique_writer_identity = true
}
