# Full SoulMate enterprise deployment
# IAP (Google Workspace SSO) + Cloud Armor + larger DB + domain access

module "soulmate" {
  source = "github.com/menonpg/soulmate-terraform"

  project_id  = "your-gcp-project-id"
  region      = "us-central1"
  admin_email = "admin@yourdomain.com"

  # Scale
  db_tier                 = "db-n1-standard-2"
  cloud_run_min_instances = 1
  cloud_run_max_instances = 50
  cloud_run_cpu           = "2"
  cloud_run_memory        = "1Gi"

  # Security
  enable_iap         = true
  enable_cloud_armor = true
  allowed_domains    = ["yourdomain.com"]   # All @yourdomain.com can access

  # Compliance
  data_retention_days = 730  # 2 years
}

output "api_url"       { value = module.soulmate.api_url }
output "logs_url"      { value = module.soulmate.logs_url }
output "monitoring_url" { value = module.soulmate.monitoring_url }
