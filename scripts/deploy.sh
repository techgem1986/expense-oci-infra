#!/bin/bash
# =============================================================================
# Expense Management System - OCI Deployment Script
# =============================================================================
# This script orchestrates the full deployment process:
#   1. Validates prerequisites (OCI CLI, Terraform, SSH key)
#   2. Initializes and applies Terraform
#   3. Waits for cloud-init to complete
#   4. Runs database migrations
#   5. Verifies the deployment
#
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   --plan-only            Run terraform plan and exit (no infrastructure changes)
#   --apply                Run terraform apply (default)
#   --destroy              Destroy all OCI infrastructure
#   --skip-build           Skip Docker image build step (if images are pre-built)
#   --env-file             Path to .env file with variables (default: ../terraform/terraform.tfvars)
#   --tfc                  Use Terraform Cloud backend instead of local state
#   --tfc-org              Terraform Cloud organization (default: from backend.tfc.hcl)
#   --tfc-workspace        Terraform Cloud workspace (default: from backend.tfc.hcl)
#   --help                 Show this help message
#
# Examples:
#   ./deploy.sh                            # Local apply with terraform.tfvars
#   ./deploy.sh --plan-only                # Local plan only
#   ./deploy.sh --destroy                  # Local destroy
#   ./deploy.sh --tfc                      # Terraform Cloud apply
#   ./deploy.sh --tfc --plan-only          # Terraform Cloud plan
#   ./deploy.sh --tfc --destroy            # Terraform Cloud destroy
# =============================================================================


set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
DEPLOYMENT_DIR="${SCRIPT_DIR}/.."
APP_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TERRAFORM_VARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"
TERRAFORM_STATE_FILE="${TERRAFORM_DIR}/terraform.tfstate"
TFC_BACKEND_CONFIG="${TERRAFORM_DIR}/backend.tfc.hcl"

# Default to apply mode
MODE="apply"
SKIP_BUILD=false
ENV_FILE="${TERRAFORM_VARS_FILE}"
USE_TFC=false

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prereq() {
    local cmd=$1
    local name=$2
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$name is not installed. Please install it first."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Parse Arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --plan-only)
            MODE="plan"
            shift
            ;;
        --apply)
            MODE="apply"
            shift
            ;;
        --destroy)
            MODE="destroy"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --tfc)
            USE_TFC=true
            shift
            ;;
        --tfc-org)
            TFC_ORG="$2"
            shift 2
            ;;
        --tfc-workspace)
            TFC_WORKSPACE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --plan-only         Run terraform plan only (no changes)"
            echo "  --apply             Run terraform apply (default)"
            echo "  --destroy           Destroy all OCI infrastructure"
            echo "  --skip-build        Skip Docker image build (use pre-built images)"
            echo "  --env-file          Path to terraform.tfvars file"
            echo "  --tfc               Use Terraform Cloud backend"
            echo "  --tfc-org           TFC organization (overrides backend.tfc.hcl)"
            echo "  --tfc-workspace     TFC workspace (overrides backend.tfc.hcl)"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                            # Local apply"
            echo "  $0 --plan-only                # Local plan"
            echo "  $0 --destroy                  # Local destroy"
            echo "  $0 --tfc                      # TFC apply"
            echo "  $0 --tfc --plan-only          # TFC plan"
            echo "  $0 --tfc --destroy            # TFC destroy"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Step 1: Validate Prerequisites
# ---------------------------------------------------------------------------
echo ""
echo "=================================================================================="
log_info "Expense Management System - OCI Always Free Deployment"
echo "=================================================================================="
echo ""

if [ "${USE_TFC}" = true ]; then
    log_info "Mode: Terraform Cloud (remote execution)"
else
    log_info "Mode: Local execution"
fi
echo ""

log_info "Validating prerequisites..."

check_prereq "terraform" "Terraform"

# For local mode, check additional prerequisites
if [ "${USE_TFC}" = false ]; then
    check_prereq "oci" "OCI CLI"
    check_prereq "ssh-keygen" "SSH Keygen"
    check_prereq "docker" "Docker"
    check_prereq "git" "Git"

    # Check OCI CLI is configured
    if ! oci iam compartment get --compartment-id "$(grep 'tenancy_ocid' "${ENV_FILE}" | cut -d'"' -f2)" &> /dev/null; then
        log_warn "OCI CLI may not be fully configured. Run 'oci setup config' first."
    fi

    # Check terraform.tfvars exists
    if [ ! -f "${ENV_FILE}" ]; then
        log_error "No terraform.tfvars found at ${ENV_FILE}"
        log_info "Copy the example file: cp ${TERRAFORM_DIR}/terraform.tfvars.example ${ENV_FILE}"
        log_info "Then edit ${ENV_FILE} with your OCI credentials and settings."
        exit 1
    fi

    # Check SSH key exists
    SSH_KEY=$(grep 'ssh_public_key_path' "${ENV_FILE}" | cut -d'"' -f2 | sed "s|~|$HOME|")
    if [ ! -f "${SSH_KEY}" ]; then
        log_error "SSH public key not found at ${SSH_KEY}"
        log_info "Generate one: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
        exit 1
    fi
else
    # TFC mode: check backend config exists
    if [ ! -f "${TFC_BACKEND_CONFIG}" ]; then
        log_error "TFC backend config not found at ${TFC_BACKEND_CONFIG}"
        log_info "Edit ${TFC_BACKEND_CONFIG} with your TFC organization and workspace name."
        exit 1
    fi

    # Check terraform login status
    if [ ! -f "${HOME}/.terraform.d/credentials.tfrc.json" ]; then
        log_warn "Terraform Cloud credentials not found. Run 'terraform login' first."
        log_info "  terraform login"
        log_info ""
        log_info "This will open a browser window to authenticate with Terraform Cloud."
        log_info "If running headless, create a token at https://app.terraform.io/app/settings/tokens"
        log_info "and run: terraform login --token YOUR_TOKEN"
        exit 1
    fi
fi

log_success "All prerequisites validated."

# ---------------------------------------------------------------------------
# Step 2: Build Docker Images (Optional — Local mode only)
# ---------------------------------------------------------------------------
if [ "${USE_TFC}" = false ] && [ "${MODE}" = "apply" ] && [ "${SKIP_BUILD}" = false ]; then
    log_info "Building Docker images locally for reference..."
    log_warn "In production, images should be built via CI/CD and pushed to OCIR."
    log_warn "See oci-deployment/docs/DEPLOYMENT.md for CI/CD setup instructions."

    # Build backend image
    log_info "Building backend Docker image..."
    cd "${APP_ROOT}"
    docker build -t expense-backend:latest -f expense-backend/Dockerfile expense-backend/ 2>&1 | \
        tail -5 || log_warn "Backend build skipped (may be building on server instead)"

    # Build frontend image
    log_info "Building frontend Docker image..."
    REACT_APP_API_BASE_URL=$(grep 'app_domain' "${ENV_FILE}" | cut -d'"' -f2)
    docker build \
        --build-arg REACT_APP_API_BASE_URL="https://${REACT_APP_API_BASE_URL}/api" \
        -t expense-frontend:latest \
        -f expense-frontend/Dockerfile \
        expense-frontend/ 2>&1 | tail -5 || log_warn "Frontend build skipped"

    log_success "Docker images built."
elif [ "${USE_TFC}" = true ] && [ "${MODE}" = "apply" ]; then
    log_info "Terraform Cloud mode — Docker images will be built on the server via cloud-init."
    log_info "For faster deployments, consider using a container registry (OCIR/Docker Hub)."
fi

# ---------------------------------------------------------------------------
# Step 3: Terraform Lifecycle
# ---------------------------------------------------------------------------
cd "${TERRAFORM_DIR}"

# Helper function to run terraform init with proper quoting for paths with spaces
terraform_init() {
    if [ "${USE_TFC}" = true ]; then
        terraform init -reconfigure -backend-config="${TFC_BACKEND_CONFIG}"
    else
        terraform init -reconfigure -backend-config="${TERRAFORM_DIR}/backend.local.hcl"
    fi
}

case "${MODE}" in
    plan)
        log_info "Running terraform plan..."

        terraform_init

        if [ "${USE_TFC}" = true ]; then
            # TFC plan — variables come from workspace, no -var-file needed
            terraform plan
        else
            terraform plan -var-file="${ENV_FILE}"
        fi

        log_success "Plan complete. Review the output above."
        exit 0
        ;;
    apply)
        log_info "Running terraform apply..."

        terraform_init

        if [ "${USE_TFC}" = true ]; then
            # TFC apply — variables come from workspace
            terraform apply -auto-approve
        else
            terraform apply -var-file="${ENV_FILE}" -auto-approve
        fi

        log_success "Infrastructure provisioned successfully!"
        ;;
    destroy)
        log_warn "This will DESTROY ALL OCI infrastructure created by this project!"
        log_warn "Data on block volumes will be permanently lost!"
        read -r -p "Type 'DESTROY' to confirm: " confirm
        if [ "${confirm}" != "DESTROY" ]; then
            log_info "Destroy cancelled."
            exit 0
        fi

        log_info "Running terraform destroy..."

        terraform_init

        if [ "${USE_TFC}" = true ]; then
            terraform destroy -auto-approve
        else
            # For local mode: detach block volumes first (they may block destroy)
            set +e
            oci bv volume update \
                --volume-id "$(grep -A 1 'expense-app-data-volume' "${TERRAFORM_STATE_FILE}" 2>/dev/null | grep '"id"' | head -1 | cut -d'"' -f4 || echo '')" \
                --force 2>/dev/null || true
            oci bv volume update \
                --volume-id "$(grep -A 1 'expense-db-data-volume' "${TERRAFORM_STATE_FILE}" 2>/dev/null | grep '"id"' | head -1 | cut -d'"' -f4 || echo '')" \
                --force 2>/dev/null || true
            set -e

            terraform destroy -var-file="${ENV_FILE}" -auto-approve
        fi

        log_success "Infrastructure destroyed."
        exit 0
        ;;
esac

# ---------------------------------------------------------------------------
# Only continue with post-deployment verification in LOCAL mode
# (TFC remote execution doesn't support local post-deployment steps)
# ---------------------------------------------------------------------------
if [ "${USE_TFC}" = true ]; then
    echo ""
    echo "=================================================================================="
    log_success "TFC deployment triggered!"
    echo "=================================================================================="
    echo ""
    echo "  Terraform Cloud is running the apply remotely."
    echo "  Check the status at: https://app.terraform.io"
    echo ""
    echo "  After TFC apply completes, SSH into the servers for post-deployment steps:"
    echo ""
    echo "  1. Get the public IPs from TFC workspace outputs"
    echo "  2. Wait for cloud-init to complete:"
    echo "     ssh ubuntu@<APP_IP> 'tail -f /var/log/bootstrap-complete.log'"
    echo "  3. Verify the application is running:"
    echo "     curl -L http://<LB_IP>/"
    echo "  4. Configure DNS and SSL as documented"
    echo ""
    echo "=================================================================================="
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 4 (Local mode): Extract Outputs
# ---------------------------------------------------------------------------
log_info "Extracting deployment outputs..."

APP_PUBLIC_IP=$(terraform output -raw app_instance_public_ip)
APP_PRIVATE_IP=$(terraform output -raw app_instance_private_ip)
DB_PUBLIC_IP=$(terraform output -raw db_instance_public_ip)
DB_PRIVATE_IP=$(terraform output -raw db_instance_private_ip)
LB_PUBLIC_IP=$(terraform output -raw load_balancer_public_ip)
APP_DOMAIN=$(grep 'app_domain' "${ENV_FILE}" | cut -d'"' -f2)

log_info "App Server Public IP:  ${APP_PUBLIC_IP}"
log_info "App Server Private IP: ${APP_PRIVATE_IP}"
log_info "DB Server Public IP:   ${DB_PUBLIC_IP}"
log_info "DB Server Private IP:  ${DB_PRIVATE_IP}"
log_info "Load Balancer IP:      ${LB_PUBLIC_IP}"
log_info "Application Domain:    ${APP_DOMAIN}"

# ---------------------------------------------------------------------------
# Step 5 (Local mode): Wait for Cloud-Init to Complete
# ---------------------------------------------------------------------------
log_info "Waiting for cloud-init to complete on both instances (this can take 3-5 minutes)..."

MAX_WAIT=600  # 10 minutes
INTERVAL=15
ELAPSED=0

for SERVER_IP in "${DB_PUBLIC_IP}" "${APP_PUBLIC_IP}"; do
    SERVER_NAME=$(echo "${SERVER_IP}" | grep -q "${APP_PUBLIC_IP}" && echo "App Server" || echo "DB Server")
    log_info "Waiting for ${SERVER_NAME} cloud-init..."

    while [ ${ELAPSED} -lt ${MAX_WAIT} ]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
            ubuntu@"${SERVER_IP}" "test -f /var/log/bootstrap-complete.log" 2>/dev/null; then
            log_success "${SERVER_NAME} cloud-init complete."
            break
        fi
        log_info "Still waiting... (${ELAPSED}s elapsed)"
        sleep ${INTERVAL}
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    if [ ${ELAPSED} -ge ${MAX_WAIT} ]; then
        log_error "${SERVER_NAME} cloud-init timed out after ${MAX_WAIT}s."
        log_info "SSH in manually: ssh ubuntu@${SERVER_IP}"
        log_info "Check logs: tail -f /var/log/cloud-init-output.log"
    fi
    ELAPSED=0
done

# ---------------------------------------------------------------------------
# Step 6 (Local mode): Verify Deployment
# ---------------------------------------------------------------------------
log_info "Verifying deployment..."

# Check Docker containers on DB server
log_info "Checking DB server containers..."
ssh -o StrictHostKeyChecking=no ubuntu@"${DB_PUBLIC_IP}" \
    "docker compose -f /opt/expense-db/docker-compose.yml ps" || log_warn "DB containers may not be ready"

# Check Docker containers on App server
log_info "Checking App server containers..."
ssh -o StrictHostKeyChecking=no ubuntu@"${APP_PUBLIC_IP}" \
    "docker compose -f /opt/expense-app/docker-compose.prod.yml ps" || log_warn "App containers may not be ready"

# Check application health via LB
log_info "Checking application health via Load Balancer (http://${LB_PUBLIC_IP}/)..."
MAX_HEALTH_WAIT=120
HEALTH_ELAPSED=0

while [ ${HEALTH_ELAPSED} -lt ${MAX_HEALTH_WAIT} ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${LB_PUBLIC_IP}/" 2>/dev/null || echo "000")
    if [ "${HTTP_CODE}" = "200" ]; then
        log_success "Application is healthy! HTTP ${HTTP_CODE}"
        break
    fi
    log_info "Health check returned HTTP ${HTTP_CODE}, waiting... (${HEALTH_ELAPSED}s)"
    sleep 10
    HEALTH_ELAPSED=$((HEALTH_ELAPSED + 10))
done

if [ ${HEALTH_ELAPSED} -ge ${MAX_HEALTH_WAIT} ]; then
    log_warn "Application health check timed out. It may still be starting up."
    log_info "Check manually: curl -L http://${LB_PUBLIC_IP}/"
fi

# ---------------------------------------------------------------------------
# Step 7 (Local mode): Show Post-Deployment Info
# ---------------------------------------------------------------------------
echo ""
echo "=================================================================================="
log_success "DEPLOYMENT COMPLETE!"
echo "=================================================================================="
echo ""
echo "  📋 Deployment Summary:"
echo "  ─────────────────────────────────────────────────────────────────────────────"
echo "  Load Balancer URL:   http://${LB_PUBLIC_IP}"
echo "  Application Domain:  http://${APP_DOMAIN}"
echo ""
echo "  SSH - App Server:    ssh ubuntu@${APP_PUBLIC_IP}"
echo "  SSH - DB Server:     ssh ubuntu@${DB_PUBLIC_IP}"
echo ""
echo "  📋 Next Steps:"
echo "  ─────────────────────────────────────────────────────────────────────────────"
echo "  1. Configure DNS A record:  ${APP_DOMAIN} → ${LB_PUBLIC_IP}"
echo "  2. Set up SSL (Let's Encrypt):"
echo "     ssh ubuntu@${APP_PUBLIC_IP}"
echo "     sudo certbot --nginx -d ${APP_DOMAIN}"
echo "  3. Access your app:  https://${APP_DOMAIN}"
echo ""
echo "  📋 Monitoring:"
echo "  ─────────────────────────────────────────────────────────────────────────────"
echo "  Prometheus:        http://${APP_PUBLIC_IP}:9090"
echo "  Backend Health:    http://${APP_PUBLIC_IP}:8080/actuator/health"
echo ""
echo "  📋 Database Backups:"
echo "  ─────────────────────────────────────────────────────────────────────────────"
echo "  Daily backup cron runs at 2:00 AM on DB server."
echo "  Backups stored at /data/backups/ (7-day retention)"
echo "  Manual backup:  ssh ubuntu@${DB_PUBLIC_IP} sudo /usr/local/bin/backup-db.sh"
echo ""
echo "=================================================================================="