# Terraform state stored in GCS — prevents "already exists" errors on re-runs
# Requires: gs://soulmate-terraform-state bucket (see BOOTSTRAP.md Step 1b)
terraform {
  backend "gcs" {
    bucket = "soulmate-terraform-state"
    prefix = "enterprise-demo"
  }
}
