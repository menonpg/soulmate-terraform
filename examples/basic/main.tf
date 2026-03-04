# Minimal SoulMate deployment — Cloud Run + Cloud SQL + Cloud Storage
# No IAP, no Cloud Armor. Good for dev/testing.

module "soulmate" {
  source = "github.com/menonpg/soulmate-terraform"

  project_id  = "your-gcp-project-id"
  region      = "us-central1"
  admin_email = "you@yourdomain.com"

  enable_iap         = false
  enable_cloud_armor = false
  db_tier            = "db-f1-micro"
}

output "api_url" {
  value = module.soulmate.api_url
}
