# Enterprise Demo — Deploy Guide

## Prerequisites
- GCP project: `soulmate-489217`
- GitHub secrets set on `menonpg/soulmate-terraform`:
  - `GCP_SERVICE_ACCOUNT_KEY` — service account JSON key
  - `GCP_PROJECT_ID` — `soulmate-489217`
  - `GCP_ADMIN_EMAIL` — admin email
  - `TF_VAR_anthropic_key` — Anthropic API key
- Docker images on Docker Hub:
  - `pgmenon/soulmate-analyst:latest`
  - `pgmenon/soulmate-comms:latest`

## Deploy Order (sequential — do NOT run in parallel, causes state lock)

Trigger each step via GitHub Actions → `GCP Deploy (Manual, One Resource at a Time)` → `workflow_dispatch`:

| Step | Target | Module |
|------|--------|--------|
| 1 | `google_project_service.run` | enterprise-demo |
| 2 | `google_service_account.demo_agent` | enterprise-demo |
| 3 | `google_project_iam_member.bq_user` | enterprise-demo |
| 4 | `google_project_iam_member.bq_viewer` | enterprise-demo |
| 5 | `google_cloud_run_v2_service.soulmate_api` | enterprise-demo |
| 6 | `google_cloud_run_v2_service_iam_member.api_public` | enterprise-demo |
| 7 | `google_cloud_run_v2_service.analyst_agent` | enterprise-demo |
| 8 | `google_cloud_run_v2_service.comms_agent` | enterprise-demo |
| 9 | `google_cloud_run_v2_service_iam_member.analyst_public` | enterprise-demo |
| 10 | `google_cloud_run_v2_service_iam_member.comms_public` | enterprise-demo |
| 11 | `google_bigquery_dataset.soulmate_demo` | enterprise-demo |
| 12 | `google_bigquery_table.q4_sales` | enterprise-demo |

> ⚠️ Steps 9 and 10 must be run one at a time — parallel runs cause GCS state lock collision.

## Live Endpoints (us-central1)

| Service | URL |
|---------|-----|
| soulmate-api | https://soulmate-api-hvky63ls3a-uc.a.run.app |
| analyst-agent | https://soulmate-analyst-hvky63ls3a-uc.a.run.app |
| comms-agent | https://soulmate-comms-hvky63ls3a-uc.a.run.app |

## Health Checks
```bash
curl https://soulmate-api-hvky63ls3a-uc.a.run.app/health
curl https://soulmate-analyst-hvky63ls3a-uc.a.run.app/health
curl https://soulmate-comms-hvky63ls3a-uc.a.run.app/health
```

## Docker Images (soulmate-agents repo)
- Build workflows push to Docker Hub only (no GCP Artifact Registry)
- Trigger manually via `workflow_dispatch` on `menonpg/soulmate-agents`
- GCP auth step intentionally removed — not needed for demo

## Known Gotchas
- SA `Owner` role on project ≠ permission to generate its own access tokens
  - If needed: grant `roles/iam.serviceAccountTokenCreator` on SA resource itself (IAM → Service Accounts → SA → Permissions tab)
- GCS state lock: only one Terraform run at a time per module
- Parallel IAM bindings = state lock 412 error — always sequential
- Cloud Run URLs follow pattern: `soulmate-{service}-hvky63ls3a-uc.a.run.app`
