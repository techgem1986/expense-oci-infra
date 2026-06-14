# Expense Management System — OCI Always Free Deployment Guide

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                        INTERNET                                        │
│                          │                                              │
│                    ┌─────▼─────┐                                       │
│                    │  DNS: A   │  expense.yourdomain.com               │
│                    │  Record   │  → LB Public IP                       │
│                    └─────┬─────┘                                       │
│                          │                                              │
│  ┌───────────────────────▼──────────────────────────────────────┐     │
│  │              OCI Always Free Tenancy                          │     │
│  │                                                               │     │
│  │  ┌──────────────────────────────────────────────────────┐    │     │
│  │  │  VCN: 10.0.0.0/16                                    │    │     │
│  │  │                                                       │    │     │
│  │  │  ┌───────────────────────────────────────────────┐   │    │     │
│  │  │  │  Flexible Load Balancer (10 Mbps, Free Tier)  │   │    │     │
│  │  │  │  HTTP:80 → App Server:80                      │   │    │     │
│  │  │  │  Health Check: / (HTTP 200)                   │   │    │     │
│  │  │  └───────────────────┬───────────────────────────┘   │    │     │
│  │  │                      │                                │    │     │
│  │  │  ┌───────────────────▼───────────────────────────┐   │    │     │
│  │  │  │  Public Subnet: 10.0.1.0/24 (App Tier)        │   │    │     │
│  │  │  │                                                │   │    │     │
│  │  │  │  ┌────────────────────────────────────────┐   │   │    │     │
│  │  │  │  │  ARM Ampere A1 (2 OCPU, 12GB RAM)      │   │   │    │     │
│  │  │  │  │  Ubuntu 24.04 LTS                       │   │   │    │     │
│  │  │  │  │                                         │   │   │    │     │
│  │  │  │  │  ┌─────────────────────────────────┐   │   │   │    │     │
│  │  │  │  │  │  Docker Compose                  │   │   │   │    │     │
│  │  │  │  │  │  ┌─────────────────────────┐    │   │   │   │    │     │
│  │  │  │  │  │  │ expense-frontend (Nginx) │    │   │   │    │     │
│  │  │  │  │  │  │ Port 80                  │    │   │   │    │     │
│  │  │  │  │  │  │ / → Static SPA           │    │   │   │    │     │
│  │  │  │  │  │  │ /api/* → Backend:8080    │    │   │   │    │     │
│  │  │  │  │  │  └─────────────────────────┘    │   │   │   │    │     │
│  │  │  │  │  │  ┌─────────────────────────┐    │   │   │   │    │     │
│  │  │  │  │  │  │ expense-backend (Java 21)│    │   │   │   │    │     │
│  │  │  │  │  │  │ Port 8080 (JVM 8GB)      │    │   │   │   │    │     │
│  │  │  │  │  │  └─────────────────────────┘    │   │   │   │    │     │
│  │  │  │  │  │  ┌─────────────────────────┐    │   │   │   │    │     │
│  │  │  │  │  │  │ Prometheus 2.55         │    │   │   │    │     │
│  │  │  │  │  │  │ Port 9090               │    │   │   │    │     │
│  │  │  │  │  │  └─────────────────────────┘    │   │   │   │    │     │
│  │  │  │  │  └─────────────────────────────────┘   │   │   │    │     │
│  │  │  │  │  Block Volume: 50GB (/data/docker-logs, │   │   │    │     │
│  │  │  │  │  /data/prometheus)                       │   │   │    │     │
│  │  │  │  └────────────────────────────────────────┘   │   │    │     │
│  │  │  └────────────────────────────────────────────────┘   │    │     │
│  │  │                      │                                  │    │     │
│  │  │  ┌───────────────────▼───────────────────────────┐     │    │     │
│  │  │  │  Public Subnet: 10.0.2.0/24 (DB Tier)        │     │    │     │
│  │  │  │                                                │     │    │     │
│  │  │  │  ┌────────────────────────────────────────┐   │     │    │     │
│  │  │  │  │  ARM Ampere A1 (2 OCPU, 12GB RAM)      │   │     │    │     │
│  │  │  │  │  Ubuntu 24.04 LTS                       │   │     │    │     │
│  │  │  │  │                                         │   │     │    │     │
│  │  │  │  │  ┌─────────────────────────────────┐   │   │     │    │     │
│  │  │  │  │  │  Docker Compose                  │   │   │     │    │     │
│  │  │  │  │  │  ┌─────────────────────────┐    │   │   │     │    │     │
│  │  │  │  │  │  │ PostgreSQL 17 (Alpine)   │    │   │   │     │    │     │
│  │  │  │  │  │  │ Port 5432               │    │   │   │     │    │     │
│  │  │  │  │  │  └─────────────────────────┘    │   │   │     │    │     │
│  │  │  │  │  │  ┌─────────────────────────┐    │   │   │     │    │     │
│  │  │  │  │  │  │ Redis 7 (Alpine)         │    │   │   │     │    │     │
│  │  │  │  │  │  │ Port 6379               │    │   │   │     │    │     │
│  │  │  │  │  │  └─────────────────────────┘    │   │   │     │    │     │
│  │  │  │  │  └─────────────────────────────────┘   │   │     │    │     │
│  │  │  │  │  Block Volume: 50GB (/data/postgresql,  │   │     │    │     │
│  │  │  │  │  /data/redis, /data/backups)             │   │     │    │     │
│  │  │  │  └────────────────────────────────────────┘   │     │    │     │
│  │  │  └────────────────────────────────────────────────┘     │    │     │
│  │  └──────────────────────────────────────────────────────────┘    │     │
│  └──────────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────────┘
```

## OCI Always Free Resource Allocation

| Resource | Limit | Used | Remaining |
|----------|-------|------|-----------|
| ARM Ampere A1 OCPUs | 4 | 4 (2×2) | 0 |
| ARM Ampere A1 RAM | 24 GB | 24 GB (2×12) | 0 |
| Block Storage | 200 GB (total) / 100 GB (free) | 100 GB (2×50) | 0 |
| Flexible Load Balancer | 1 (10 Mbps) | 1 | 0 |
| Outbound Data Transfer | 10 TB/month | ~variable | — |
| Object Storage | 10 GB | 0 | 10 GB |

> **Note:** OCI Always Free resources may vary by region. Verify availability in your chosen region (default: ap-hyderabad-1).

---

## Prerequisites

### 1. OCI Account Setup

```bash
# Install OCI CLI
brew install oci-cli

# Configure OCI CLI (generates ~/.oci/config and API keys)
oci setup config
# Follow prompts: enter tenancy OCID, user OCID, region, key path

# Upload your public API key to OCI Console
# Profile → User Settings → API Keys → Add API Key
# Paste contents of ~/.oci/oci_api_key_public.pem
```

### 2. Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | ≥ 1.9.0 | Infrastructure as Code |
| OCI CLI | ≥ 3.0 | Oracle Cloud CLI |
| Docker | ≥ 24.0 | Container build |
| Git | ≥ 2.30 | Source code |
| SSH Key | RSA 4096 | Instance access |

### 3. Generate SSH Key (if needed)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "oci-expense-app"
```

---

## Quick Start (3-Step Deployment)

### Step 1: Configure Variables

```bash
cd expense-oci-infra/terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
#   - OCI credentials (tenancy_ocid, user_ocid, fingerprint, private_key_path)
#   - SSH public key path
#   - Application domain name
#   - Secure database password (32+ characters)
#   - Secure JWT secret (32+ characters)
#   - Your home/office IP for SSH whitelisting
vim terraform.tfvars
```

### Step 2: Deploy

```bash
cd expense-oci-infra/scripts
chmod +x deploy.sh

# Preview infrastructure changes first:
./deploy.sh --plan-only

# Deploy everything:
./deploy.sh --apply
```

The script will:
1. Validate all prerequisites
2. Run `terraform init && terraform apply`
3. Wait for cloud-init to bootstrap both servers
4. Verify the application is healthy

### Step 3: Configure DNS & SSL

```bash
# 1. Create a DNS A record:
#    expense.yourdomain.com → <Load Balancer Public IP>

# 2. SSH into the app server:
ssh ubuntu@<APP_PUBLIC_IP>

# 3. Run certbot for Let's Encrypt SSL:
sudo certbot --nginx -d expense.yourdomain.com

# 4. Verify HTTPS:
curl -I https://expense.yourdomain.com
```

---

## Infrastructure Details

### Terraform Resources Created

| Resource | Purpose |
|----------|---------|
| `oci_core_vcn` | Virtual Cloud Network (10.0.0.0/16) |
| `oci_core_internet_gateway` | Internet access |
| `oci_core_subnet` × 2 | App subnet (10.0.1.0/24) + DB subnet (10.0.2.0/24) |
| `oci_core_security_list` × 2 | App ingress rules + DB ingress rules |
| `oci_core_instance` × 2 | 2 ARM Ampere A1 VMs (2 OCPU, 12GB each) |
| `oci_core_volume` × 2 | 2 × 50GB block volumes |
| `oci_load_balancer` | Flexible LB (10 Mbps) |

### Technology Stack

| Component | Version |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| Java | 21 (Eclipse Temurin) |
| Node.js | 22 LTS |
| PostgreSQL | 17 Alpine |
| Redis | 7 Alpine |
| Prometheus | 2.55.1 |
| Node Exporter | 1.9.1 |
| Docker Compose | Latest (standalone plugin) |
| Nginx | Latest (Alpine) |

### Network Security Rules

**App Subnet Ingress:**
- TCP/80 (HTTP) from 0.0.0.0/0
- TCP/443 (HTTPS) from 0.0.0.0/0
- TCP/22 (SSH) from your configured IP only
- TCP/8080 from app subnet + DB subnet (internal backend access)
- TCP/9100 from app subnet (Prometheus Node Exporter)

**DB Subnet Ingress:**
- TCP/5432 from app subnet ONLY (PostgreSQL)
- TCP/6379 from app subnet ONLY (Redis)
- TCP/22 (SSH) from your configured IP only
- TCP/9100 from app subnet (Prometheus Node Exporter)

---

## Maintenance Operations

### SSH into Instances

```bash
# App server
ssh ubuntu@<APP_PUBLIC_IP>

# DB server
ssh ubuntu@<DB_PUBLIC_IP>
```

### Check Service Status

```bash
# On App server
docker compose -f /opt/expense-app/docker-compose.prod.yml ps
docker compose -f /opt/expense-app/docker-compose.prod.yml logs -f --tail=100

# On DB server
docker compose -f /opt/expense-db/docker-compose.yml ps
docker compose -f /opt/expense-db/docker-compose.yml logs -f --tail=100
```

### Restart Services

```bash
# Restart application stack (on app server)
cd /opt/expense-app && docker compose -f docker-compose.prod.yml restart

# Restart database stack (on DB server)
cd /opt/expense-db && docker compose -f docker-compose.yml restart

# Full restart (on app server)
cd /opt/expense-app && docker compose -f docker-compose.prod.yml down && docker compose -f docker-compose.prod.yml up -d
```

### Database Backups

```bash
# Automatic: Daily at 2:00 AM via cron, 7-day retention
# Location: /data/backups/ on DB server

# Manual backup
ssh ubuntu@<DB_PUBLIC_IP> sudo /usr/local/bin/backup-db.sh

# List backups
ssh ubuntu@<DB_PUBLIC_IP> ls -lh /data/backups/

# Restore from backup (manual process)
ssh ubuntu@<DB_PUBLIC_IP>
cd /opt/expense-db
gunzip -c /data/backups/expense_db_TIMESTAMP.sql.gz | \
  docker exec -i expense-postgres psql -U postgres expense_db
```

### View Logs

```bash
# Application logs (on app server)
docker compose -f /opt/expense-app/docker-compose.prod.yml logs -f backend
docker compose -f /opt/expense-app/docker-compose.prod.yml logs -f frontend

# Database logs (on DB server)
docker compose -f /opt/expense-db/docker-compose.yml logs -f postgres

# System logs
tail -f /var/log/cloud-init-output.log
journalctl -u docker -f
```

### Update Application

```bash
# 1. SSH to app server
ssh ubuntu@<APP_PUBLIC_IP>

# 2. Pull latest code
cd /opt/expense-app/source
git pull origin main

# 3. Rebuild and restart
docker build -t expense-backend:latest -f expense-backend/Dockerfile expense-backend/
docker build \
  --build-arg REACT_APP_API_BASE_URL=https://expense.yourdomain.com/api \
  -t expense-frontend:latest \
  -f expense-frontend/Dockerfile \
  expense-frontend/

# 4. Restart stack
cd /opt/expense-app
docker compose -f docker-compose.prod.yml up -d
```

---

## Monitoring

### Prometheus (on App Server)

```
http://<APP_PUBLIC_IP>:9090/
```

### Spring Boot Actuator Endpoints

```
# Health check
http://<APP_PUBLIC_IP>:8080/actuator/health

# Metrics (Prometheus format)
http://<APP_PUBLIC_IP>:8080/actuator/prometheus

# Full info
http://<APP_PUBLIC_IP>:8080/actuator/info
```

### Grafana Cloud (Optional)

If you configure `grafana_cloud_api_key` and `grafana_cloud_prometheus_url` in `terraform.tfvars`, the Prometheus instance on the app server will remote-write metrics to Grafana Cloud.

---

## Terraform State Management

The deployment defaults to **local state** (`terraform.tfstate` in the terraform directory). For team use or CI/CD, migrate to **Terraform Cloud**:

### Option 1: Terraform Cloud (Recommended)

See [README.md](../README) for full setup instructions.

Quick start:
```bash
# 1. Edit backend.tfc.hcl with your TFC org and workspace
vim expense-oci-infra/terraform/backend.tfc.hcl

# 2. Authenticate with Terraform Cloud
terraform login

# 3. Initialize with TFC backend (pushes local state to TFC)
cd expense-oci-infra/terraform
terraform init -backend-config=backend.tfc.hcl -reconfigure

# 4. Use the deploy script with --tfc flag
cd expense-oci-infra/scripts
./deploy.sh --tfc --plan-only   # Preview
./deploy.sh --tfc               # Apply
./deploy.sh --tfc --destroy     # Destroy
```

### Option 2: OCI Object Storage (Alternative)

```bash
# Create an OCI Object Storage bucket for state
oci os bucket create \
  --compartment-id <tenancy_ocid> \
  --name expense-terraform-state

# Update provider.tf backend (uncomment the S3 backend block):
# backend "s3" {
#   bucket   = "expense-terraform-state"
#   key      = "terraform.tfstate"
#   endpoint = "https://<namespace>.compat.objectstorage.<region>.oraclecloud.com"
#   ...
# }
```

---

## Scaling (Within Always Free)

| Scenario | Action |
|----------|--------|
| Need more backend compute | Reduce DB instance to 1 OCPU / 6GB, increase app to 3 OCPU / 18GB |
| PostgreSQL needs more memory | Reduce app instance, increase DB instance |
| Need more storage | 100GB is the free tier limit; upgrade to paid or add object storage for backups |
| Need high availability | Always Free supports 2 instances—already at maximum; consider cross-region |

---

## Troubleshooting

### Cloud-Init Fails

```bash
# Check cloud-init status
ssh ubuntu@<IP>
sudo cloud-init status --long

# View output log
sudo tail -f /var/log/cloud-init-output.log

# Manually re-run specific steps if needed
```

### Docker Service Won't Start

```bash
# Check Docker daemon
sudo systemctl status docker
sudo journalctl -u docker -f

# Check container logs
docker compose -f /opt/expense-app/docker-compose.prod.yml logs
```

### Backend Can't Connect to PostgreSQL

```bash
# From app server, test connectivity to DB server
nc -zv <DB_PRIVATE_IP> 5432

# Check security list rules (OCI Console → Networking → Security Lists)

# Check PostgreSQL is running
ssh ubuntu@<DB_PUBLIC_IP>
docker compose -f /opt/expense-db/docker-compose.yml ps
```

### Load Balancer Returns 502

```bash
# Check backend health on the LB
# OCI Console → Networking → Load Balancers → Backend Sets → Health

# Verify Nginx is serving
ssh ubuntu@<APP_PUBLIC_IP>
curl -I http://localhost:80/

# Verify backend is healthy
ssh ubuntu@<APP_PUBLIC_IP>
curl http://localhost:8080/actuator/health
```

---

## Tear Down

```bash
cd expense-oci-infra/scripts
./deploy.sh --destroy
```

> ⚠️ **Warning:** This permanently deletes all OCI resources and data. Back up your database first.

---

## File Structure Reference

```
expense-oci-infra/
├── terraform/
│   ├── provider.tf          # OCI provider & Terraform config
│   ├── variables.tf         # Input variables
│   ├── data.tf              # Data sources & locals
│   ├── networking.tf        # VCN, subnets, gateways, security lists
│   ├── compute.tf           # Compute instances & cloud-init
│   ├── volumes.tf           # Block volumes & attachments
│   ├── loadbalancer.tf      # Flexible load balancer
│   ├── outputs.tf           # Output values
│   ├── terraform.tfvars.example  # Variable values template
│   └── cloud-init/
│       ├── app-cloud-init.yaml   # App server bootstrap
│       └── db-cloud-init.yaml    # DB server bootstrap
├── docker/
│   ├── backend.Dockerfile   # Production backend Dockerfile
│   └── frontend.Dockerfile  # Production frontend Dockerfile
├── conf/
│   └── nginx.prod.conf      # Production Nginx configuration
├── docs/
│   └── DEPLOYMENT.md        # This file
└── scripts/
    └── deploy.sh            # Deployment automation script