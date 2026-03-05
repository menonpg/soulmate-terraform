# ── SoulMate × Ingram Micro — Live Demo Infrastructure ───────────────────────
#
# What this deploys (one resource at a time via GitHub Actions):
#
#   1. google_cloud_run_v2_service.soulmate_api   — core API
#   2. google_cloud_run_v2_service.analyst_agent  — SQL + BigQuery agent
#   3. google_cloud_run_v2_service.comms_agent    — email summary agent
#   4. google_bigquery_dataset.demo               — sample sales data
#   5. google_bigquery_table.sales                — Q4 sales table
#
# Frontend: soulmate.thinkcreateai.com/demo/ (GitHub Pages, calls these APIs)
# Demo flow:
#   User asks "How did Q4 sales trend?"
#   → Router → Analyst Agent (Gemma 2B SQL gen) → BigQuery
#   → A2A handoff → Comms Agent (Gemini reasoning) → email draft
#   → Results back to UI

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "project_id"     { default = "soulmate-489217" }
variable "region"         { default = "us-central1" }
variable "anthropic_key"  { sensitive = true }
variable "demo_image"     { default = "pgmenon/soulmate-api:latest" }

# ── Enable APIs (one-time, safe to apply all at once) ─────────────────────────

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "bigquery.googleapis.com",
    "aiplatform.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# ── Service Account for demo agents ───────────────────────────────────────────

resource "google_service_account" "demo_agent" {
  account_id   = "soulmate-demo-agent"
  display_name = "SoulMate Demo Agent SA"
}

resource "google_project_iam_member" "bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.demo_agent.email}"
}

resource "google_project_iam_member" "bigquery_data_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.demo_agent.email}"
}

# ── Step 1: SoulMate API (core) ───────────────────────────────────────────────

resource "google_cloud_run_v2_service" "soulmate_api" {
  name     = "soulmate-api"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  depends_on = [google_project_service.apis]

  template {
    service_account = google_service_account.demo_agent.email
    containers {
      image = var.demo_image
      env { name = "ANTHROPIC_API_KEY", value = var.anthropic_key }
      env { name = "SOUL_LEGACY_MODE",  value = "cloud" }
      resources { limits = { cpu = "1", memory = "512Mi" } }
      liveness_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 10
      }
    }
    scaling { min_instance_count = 0, max_instance_count = 3 }
  }
}

resource "google_cloud_run_v2_service_iam_member" "api_public" {
  location = google_cloud_run_v2_service.soulmate_api.location
  name     = google_cloud_run_v2_service.soulmate_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Step 2: Analyst Agent ─────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "analyst_agent" {
  name     = "soulmate-analyst"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  depends_on = [google_project_service.apis]

  template {
    service_account = google_service_account.demo_agent.email
    containers {
      image = "pgmenon/soulmate-analyst:latest"
      env { name = "ANTHROPIC_API_KEY",  value = var.anthropic_key }
      env { name = "GCP_PROJECT",        value = var.project_id }
      env { name = "COMMS_AGENT_URL",
            value = "https://soulmate-comms-${var.project_id}.run.app" }
      resources { limits = { cpu = "1", memory = "512Mi" } }
    }
    scaling { min_instance_count = 0, max_instance_count = 3 }
  }
}

resource "google_cloud_run_v2_service_iam_member" "analyst_public" {
  location = google_cloud_run_v2_service.analyst_agent.location
  name     = google_cloud_run_v2_service.analyst_agent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Step 3: Comms Agent ───────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "comms_agent" {
  name     = "soulmate-comms"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  depends_on = [google_project_service.apis]

  template {
    service_account = google_service_account.demo_agent.email
    containers {
      image = "pgmenon/soulmate-comms:latest"
      env { name = "ANTHROPIC_API_KEY", value = var.anthropic_key }
      resources { limits = { cpu = "1", memory = "512Mi" } }
    }
    scaling { min_instance_count = 0, max_instance_count = 3 }
  }
}

resource "google_cloud_run_v2_service_iam_member" "comms_public" {
  location = google_cloud_run_v2_service.comms_agent.location
  name     = google_cloud_run_v2_service.comms_agent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Step 4 + 5: BigQuery demo dataset + sales table ──────────────────────────

resource "google_bigquery_dataset" "demo" {
  dataset_id    = "soulmate_demo"
  friendly_name = "SoulMate Demo Dataset"
  location      = "US"
  depends_on    = [google_project_service.apis]
}

resource "google_bigquery_table" "sales" {
  dataset_id = google_bigquery_dataset.demo.dataset_id
  table_id   = "q4_sales"
  deletion_protection = false

  schema = jsonencode([
    { name = "date",        type = "DATE",    mode = "REQUIRED" },
    { name = "region",      type = "STRING",  mode = "REQUIRED" },
    { name = "product",     type = "STRING",  mode = "REQUIRED" },
    { name = "revenue",     type = "FLOAT64", mode = "REQUIRED" },
    { name = "units_sold",  type = "INTEGER", mode = "REQUIRED" },
    { name = "partner_id",  type = "STRING",  mode = "NULLABLE" },
  ])
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "api_url"      { value = google_cloud_run_v2_service.soulmate_api.uri }
output "analyst_url"  { value = google_cloud_run_v2_service.analyst_agent.uri }
output "comms_url"    { value = google_cloud_run_v2_service.comms_agent.uri }
output "bq_dataset"   { value = google_bigquery_dataset.demo.dataset_id }
