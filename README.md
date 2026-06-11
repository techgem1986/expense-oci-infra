# Terraform Cloud Setup for OCI Deployment

This document explains how to set up Terraform Cloud to manage the OCI infrastructure for the Expense Management System.

## Overview

```
┌─────────────────────┐          ┌──────────────────────┐
│                     │          │                      │
│   GitHub Actions    │  triggers│  Terraform Cloud      │
│   (CI/CD pipeline)  │─────────►│  (Remote Execution)   │
│                     │          │                      │
└─────────────────────┘          └──────────┬───────────┘
                                            │
                                            │ OCI Provider
                                            │ (API Key Auth)
                                            ▼
                                    ┌────────────────┐
                                    │                │
                                    │  OCI Tenancy   │
                                    │                │
                                    └────────────────┘
```

## Prerequisites

1. **Terraform Cloud account** — Sign up at [app.terraform.io](https://app.terraform.io)
2. **GitHub repository** — Your Expense Management System repo
3. **OCI API key** — Already configured for local deployment

---

## Step 1: Create Terraform Cloud Organization & Workspace

### 1.1 Create Organization

1. Log in to [app.terraform.io](https://app.terraform.io)
2. Click **Create organization**
3. Name it (e.g., `expense-management`)
4. Choose the Free plan (includes 5 users, 500 resources — sufficient for this project)

### 1.2 Create Workspace

1. Go to your organization → **Workspaces** → **New workspace**
2. Choose **Version control workflow**
3. Select **GitHub** (or your provider)
4. Connect your repository (`your-org/expense-management-system`)
5. Set workspace name: `expense-management-oci`
6. Set **Terraform Working Directory** to: `oci-deployment/terraform`
7. Click **Create workspace**

---

## Step 2: Configure Workspace Variables

All sensitive variables must be marked as **sensitive** in Terraform Cloud.

### Environment Variables (for the TFC agent/runner)

| Variable | Value | Sensitive |
|----------|-------|-----------|
| `TFE_TOKEN` | Your Terraform Cloud API token | Yes |

### Terraform Variables

Set these in the workspace **Variables** tab (Terraform Variables section):

#### Required — OCI Authentication

| Variable | Value | Sensitive |
|----------|-------|-----------|
| `tenancy_ocid` | `ocid1.tenancy.oc1..aaaaaaa...` | Yes |
| `user_ocid` | `ocid1.user.oc1..aaaaaaa...` | Yes |
| `fingerprint` | `xx:xx:xx:xx:xx:...` | Yes |
| `oci_private_key` | Full PEM content of your OCI API key | Yes |
| `oci_region` | `ap-mumbai-1` | No |

> **How to get `oci_private_key` contents:**
> ```bash
> cat ~/.oci/oci_api_key.pem
> ```
> Copy the entire output (from `-----BEGIN PRIVATE KEY-----` to `-----END PRIVATE KEY-----`) and paste it as the variable value.

#### Required — Application Secrets

| Variable | Value | Sensitive |
|----------|-------|-----------|
| `db_password` | Your PostgreSQL password (32+ chars) | Yes |
| `jwt_secret` | Your JWT secret (32+ chars) | Yes |
| `app_domain` | `expense.yourdomain.com` | No |
| `ssh_public_key` | Contents of `~/.ssh/id_rsa.pub` | No |
| `ssh_allowed_ip` | `0.0.0.0/0` (or your IP) | No |

> **How to get `ssh_public_key` contents:**
> ```bash
> cat ~/.ssh/id_rsa.pub
> ```

#### Optional

| Variable | Value | Sensitive |
|----------|-------|-----------|
| `grafana_cloud_api_key` | Your Grafana Cloud API key | Yes |
| `grafana_cloud_prometheus_url` | Your Grafana Cloud Prometheus URL | No |

---

## Step 3: Connect GitHub Actions to Terraform Cloud

### 3.1 Create a Terraform Cloud API Token

1. Go to **Settings** → **User settings** → **Tokens**
2. Click **Create an API token**
3. Name it (e.g., `github-actions`)
4. Copy the token value (it starts with `xxxxxxxx.atlasv1.xxx`)

### 3.2 Add Token to GitHub Secrets

1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `TF_API_TOKEN`
4. Value: Paste the TFC API token
5. Click **Add secret**

---

## Step 4: Using Terraform Cloud

### Plan (Preview Changes)

```bash
# From GitHub: Open a Pull Request → TFC auto-runs plan
# Or manually via TFC UI: Workspace → Queue Plan

# Or from CLI (if using TFC CLI-driven workflow):
cd oci-deployment/terraform
terraform login
terraform init -backend-config=backend.tfc.hcl -reconfigure
terraform plan
```

### Apply (Deploy)

```bash
# Option A: Via GitHub (triggered by push to main branch)
git push origin main

# Option B: Via TFC UI
# Workspace → Queue Plan → Confirm → Apply

# Option C: Via CLI (if using CLI-driven workflow)
cd oci-deployment/terraform
terraform apply
```

### Destroy (Teardown)

```bash
# Via TFC UI: Workspace → Settings → Destruction and Deletion
# Then: Queue Destroy Plan → Confirm
```

---

## Step 5: Manual Steps (After First Deploy)

Even with Terraform Cloud, these manual steps are still needed:

1. **Configure DNS** — Point your domain's A record to the Load Balancer IP
2. **Set up SSL** — SSH into the app server and run certbot
3. **Verify health** — Check the application is running correctly

---

## Migration: Local → Terraform Cloud

If you already have infrastructure deployed with local state:

```bash
# 1. Push local state to TFC
cd oci-deployment/terraform
terraform login
terraform init -backend-config=backend.tfc.hcl -reconfigure

# Terraform will prompt to copy existing state to TFC. Confirm yes.

# 2. Verify state is migrated
terraform state list

# 3. From now on, use TFC for all operations
```

---

## Cost

| Service | Cost |
|---------|------|
| Terraform Cloud Free Plan | Free (5 users, 500 resources) |
| GitHub Actions Free Plan | Free (2000 min/month, 500 MB storage) |
| OCI Always Free | Free (as long as you stay within Always Free limits) |

**Total Monthly Cost: $0**