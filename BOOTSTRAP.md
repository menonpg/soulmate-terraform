# GCP Bootstrap — One-Time Manual Steps

Before Terraform can manage anything, GCP needs a few APIs enabled manually.
This is the chicken-and-egg problem: Terraform needs APIs to enable APIs.

**Do these once, in order, before running any GitHub Actions workflows.**

---

## Step 0 — GCP Account & Project

- Project: `soulmate-489217`
- Project number: `315394193472`
- Billing account: `012201-7E03A1-888C82`
- Admin: `pmenon@aats.org`

> ⚠️ This account was previously suspended due to Terraform spinning up
> too many resources at once. Always use targeted deploys — one resource
> at a time via GitHub Actions workflow_dispatch.

---

## Step 1 — Enable Cloud Resource Manager API (manual, required first)

Terraform cannot enable any APIs until this one is on — it's the bootstrap API.

👉 [Enable Cloud Resource Manager API](https://console.developers.google.com/apis/api/cloudresourcemanager.googleapis.com/overview?project=315394193472)

Click **Enable** → wait 60 seconds.

**Status: ✅ Done (2026-03-05)**

### Also enable manually (same reason — bootstrap APIs):

👉 [Enable IAM API](https://console.developers.google.com/apis/api/iam.googleapis.com/overview?project=315394193472)

👉 [Enable Service Usage API](https://console.developers.google.com/apis/api/serviceusage.googleapis.com/overview?project=315394193472)

👉 [Enable Cloud Run API](https://console.developers.google.com/apis/api/run.googleapis.com/overview?project=315394193472)

👉 [Enable BigQuery API](https://console.developers.google.com/apis/api/bigquery.googleapis.com/overview?project=315394193472)

Enable all of these before running any Terraform. Saves multiple retry cycles.

**Status: ✅ Done (2026-03-05)**


---

## Step 1b — Create Terraform State Bucket (manual, required)

Without a state backend, Terraform forgets what it's already created and
tries to recreate resources on every run — causing "already exists" errors.

1. Go to [Cloud Storage](https://console.cloud.google.com/storage/browser?project=soulmate-489217) → **Create bucket**
2. Name: `soulmate-terraform-state`
3. Region: `us-central1`
4. Access: uniform, no public access
5. Everything else default → **Create**

**Status: ⏳ Pending**

Then the `backend.tf` in this repo will automatically use it for state storage.
All "already exists" errors disappear once state is working.

---

## Step 2 — Grant Service Account Permissions (manual)

Service account: `soulmate-terraform@soulmate-489217.iam.gserviceaccount.com`

1. Go to [IAM & Admin → IAM](https://console.cloud.google.com/iam-admin/iam?project=soulmate-489217)
2. Find the service account
3. Assign role: **Owner** (or at minimum: Editor + Service Usage Admin)

**Status: ✅ Done (2026-03-05)**

---

## Step 3 — Set GitHub Secrets (one-time)

In [soulmate-terraform → Settings → Secrets](https://github.com/menonpg/soulmate-terraform/settings/secrets/actions):

| Secret | Value |
|--------|-------|
| `GCP_SERVICE_ACCOUNT_KEY` | JSON key for the service account (from api_keys.json) |
| `GCP_PROJECT_ID` | `soulmate-489217` |
| `GCP_ADMIN_EMAIL` | `pmenon@aats.org` |
| `TF_VAR_anthropic_key` | Anthropic API key (from api_keys.json) |

**Status: ✅ Done (2026-03-05)**

---

## After Bootstrap — Deploy Order

Use GitHub Actions → **GCP Deploy** workflow.
**Always plan first, then apply. One resource at a time.**

| Step | Target | Status | Notes |
|------|--------|--------|-------|
| 1 | `google_project_service.apis` | ✅ Done | APIs enabled |
| 2 | `google_service_account.demo_agent` | ✅ Done | |
| 3 | `google_project_iam_member.bq_user` | ✅ Done | |
| 4 | `google_project_iam_member.bq_viewer` | ✅ Done | |
| 5 | `google_cloud_run_v2_service.soulmate_api` | ✅ Done | Live: https://soulmate-api-hvky63ls3a-uc.a.run.app |
| 6 | `google_cloud_run_v2_service_iam_member.api_public` | ✅ Done | Public, health check passing |
| 7 | `google_cloud_run_v2_service.analyst_agent` | ⏳ Blocked | Needs pgmenon/soulmate-analyst Docker image built first |
| 8 | `google_cloud_run_v2_service.comms_agent` | ⏳ Blocked | Needs pgmenon/soulmate-comms Docker image built first |
| 9 | `google_bigquery_dataset.demo` | ✅ Done | dataset: soulmate_demo |
| 10 | `google_bigquery_table.sales` | ✅ Done | table: q4_sales |

## What's Blocking Steps 7 & 8

The analyst and comms agents need their own Docker images:
- `pgmenon/soulmate-analyst:latest` — SQL generation agent (Gemma 2B / Anthropic)
- `pgmenon/soulmate-comms:latest` — email summary agent (Gemini / Anthropic)

These need to be built as separate FastAPI services and pushed to Docker Hub.
See next section for build plan.

## Next Build: Agent Docker Images

### soulmate-analyst
- FastAPI service
- Accepts: `POST /analyze { question: str }`
- Flow: route question → generate SQL (Anthropic) → execute on BigQuery → return results + A2A handoff to comms
- Env vars needed: `ANTHROPIC_API_KEY`, `GCP_PROJECT`, `COMMS_AGENT_URL`
- Repo to create: `menonpg/soulmate-agents` (monorepo: analyst/ + comms/)

### soulmate-comms
- FastAPI service  
- Accepts: `POST /summarize { data: dict, question: str }`
- Flow: take BigQuery results → draft email summary (Anthropic) → return draft
- Env vars needed: `ANTHROPIC_API_KEY`

> ⚠️ Wait and verify each service is healthy before moving to the next.
> Do not batch multiple Cloud Run services in one apply.

---

## Lessons Learned

- **Don't run `terraform apply` without `-target`** — caused the original suspension
- **Cloud Resource Manager API must be enabled manually first** — always
- **Service account needs Owner or Editor + Service Usage Admin** — less than that fails silently on plan but errors on apply
- **GCP propagates IAM changes slowly** — after granting roles, wait 60s before re-running
