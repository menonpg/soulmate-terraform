# soulmate-terraform

One-click GCP deployment for [SoulMate](https://menonpg.github.io/soulmate/) — persistent AI memory infrastructure.

Deploys the full production stack to any GCP project in minutes:

- **Cloud Run** — SoulMate API (auto-scaling, serverless)
- **Cloud SQL** — PostgreSQL for accounts + usage tracking
- **Cloud Storage** — Persistent memory files (versioned)
- **Secret Manager** — Zero plaintext credentials
- **IAP** — Google Workspace SSO (optional)
- **Cloud Logging** — Full audit trail
- **Cloud Armor** — WAF/DDoS protection (optional)

---

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI authenticated
- Terraform >= 1.5

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

---

## Quick Deploy

```bash
git clone https://github.com/menonpg/soulmate-terraform
cd soulmate-terraform

terraform init
terraform apply \
  -var="project_id=your-gcp-project" \
  -var="region=us-central1" \
  -var="admin_email=you@yourdomain.com"
```

After ~5 minutes:

```
Outputs:
api_url         = https://soulmate-xxxxx-uc.a.run.app
memory_bucket   = your-project-soulmate-memory
monitoring_url  = https://console.cloud.google.com/monitoring/...
logs_url        = https://console.cloud.google.com/logs/...
```

---

## Examples

### Basic (dev/testing)
```bash
cd examples/basic
terraform init && terraform apply
```

### Enterprise (IAP + Cloud Armor + larger DB)
```bash
cd examples/enterprise
# Edit main.tf with your project_id, admin_email, allowed_domains
terraform init && terraform apply
```

---

## Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `project_id` | ✅ | — | GCP project ID |
| `region` | | `us-central1` | GCP region |
| `admin_email` | ✅ | — | Admin email (gets IAP + IAM access) |
| `app_name` | | `soulmate` | Resource name prefix |
| `db_tier` | | `db-f1-micro` | Cloud SQL tier |
| `cloud_run_memory` | | `512Mi` | Memory per Cloud Run instance |
| `enable_iap` | | `true` | Google Workspace SSO |
| `enable_cloud_armor` | | `false` | WAF/DDoS protection |
| `allowed_domains` | | `[]` | Email domains with IAP access |
| `data_retention_days` | | `365` | Audit log retention |

---

## Security

- No public IP on Cloud SQL — Cloud Run connects via Unix socket
- All credentials stored in Secret Manager — zero plaintext in environment
- IAP enforces Google Workspace identity before any request reaches the API
- Memory files versioned in Cloud Storage — full history, point-in-time restore
- Audit log captures every memory read, write, and delete

---

## Related

- [SoulMate](https://menonpg.github.io/soulmate/) — pitch deck + signup
- [soul-agent](https://pypi.org/project/soul-agent/) — Python SDK (`pip install soul-agent`)
- [soul.py](https://github.com/menonpg/soul.py) — open source memory library
- [soul-schema](https://github.com/menonpg/soul-schema) — auto-document your database schema

---

## License

MIT
