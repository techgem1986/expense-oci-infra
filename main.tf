# =============================================================================
# Expense Management System — OCI Terraform (Root Module)
# =============================================================================
# The root entry point sources the terraform/ subdirectory as a child module.
#
#   expense-oci-infra/
#   ├── main.tf              ← YOU ARE HERE (root: terraform {}, provider, module)
#   ├── terraform.tfvars     ← sensitive values (gitignored)
#   ├── terraform.tfvars.example
#   └── terraform/           ← child module (resources)
#       ├── provider.tf       ← required_providers only
#       ├── variables.tf      ← module input variables
#       ├── data.tf
#       ├── networking.tf
#       ├── compute.tf
#       ├── volumes.tf
#       ├── loadbalancer.tf
#       ├── outputs.tf
#       ├── cloud-init/
#       ├── backend.local.hcl
#       └── backend.tfc.hcl
#
# ---------------------------------------------------------------------------
# Architecture (see terraform/ for the ASCII diagram)
# ---------------------------------------------------------------------------
#   Internet → OCI Flexible LB (10 Mbps) → VCN (10.0.0.0/16)
#     ├── App Subnet  (10.0.1.0/24) → ARM Ampere A1 (2 OCPU / 12 GB)
#     │     Docker Compose: Nginx + Spring Boot + Prometheus
#     │     Block Volume 50 GB (docker data, logs)
#     └── DB Subnet   (10.0.2.0/24) → ARM Ampere A1 (2 OCPU / 12 GB)
#           Docker Compose: PostgreSQL 15 + Redis 7
#           Block Volume 50 GB (PGDATA, Redis AOF/RDB)
#
# ---------------------------------------------------------------------------
# Always Free Tier Allocation
# ---------------------------------------------------------------------------
#   Compute  2 × VM.Standard.A1.Flex  (4 OCPU / 24 GB total)   ✓ maxed
#   Storage  2 × 50 GB Block Volumes   (100 GB total)           ✓ maxed
#   Network  1 × Flexible LB           (10 Mbps)                ✓ maxed
#   Boot     2 × boot volumes          (~47 GB each, included)
#
# ---------------------------------------------------------------------------
# Quick Start
# ---------------------------------------------------------------------------
#   Local:
#     cd expense-oci-infra
#     cp terraform.tfvars.example terraform.tfvars     # fill in secrets
#     terraform init -backend-config=terraform/backend.local.hcl
#     terraform plan
#     terraform apply
#
#   Terraform Cloud (CI):
#     cd expense-oci-infra
#     terraform init -backend-config=terraform/backend.tfc.hcl -reconfigure
#     terraform apply
#
#   GitHub Actions:
#     Push to main → .github/workflows/terraform.yml triggers apply
# =============================================================================

# ---------------------------------------------------------------------------
# Terraform & Provider Requirements
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend is configured at init time via -backend-config:
  #   Local:           terraform init -backend-config=terraform/backend.local.hcl
  #   Terraform Cloud: terraform init -backend-config=terraform/backend.tfc.hcl -reconfigure
}

# NOTE: The OCI provider block lives in terraform/provider.tf (the child module).
# Variables declared above are forwarded to the child module below.
# ---------------------------------------------------------------------------

# =============================================================================
# Root Input Variables
# =============================================================================
# These mirror the child module's variables so values can be set via
# terraform.tfvars or TF_VAR_* environment variables at the root level.
# =============================================================================

# --- Authentication ---
variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "API signing key fingerprint"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to the API signing private key (local execution; ignored when oci_private_key is set)"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "oci_private_key" {
  description = "OCI API signing private key PEM content (TFC remote execution; supersedes private_key_path)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "oci_region" {
  description = "OCI region identifier"
  type        = string
  default     = "ap-mumbai-1"
}

# --- Networking ---
variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_app_cidr" {
  description = "CIDR block for the application public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_db_cidr" {
  description = "CIDR block for the database public subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# --- Compute ---
variable "app_instance_shape" {
  description = "Compute shape for the application server (ARM Always Free)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "app_instance_ocpus" {
  description = "Number of OCPUs for the application server"
  type        = number
  default     = 2
}

variable "app_instance_memory_gb" {
  description = "Memory in GB for the application server"
  type        = number
  default     = 12
}

variable "db_instance_shape" {
  description = "Compute shape for the database server (ARM Always Free)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "db_instance_ocpus" {
  description = "Number of OCPUs for the database server"
  type        = number
  default     = 2
}

variable "db_instance_memory_gb" {
  description = "Memory in GB for the database server"
  type        = number
  default     = 12
}

# --- OS Image ---
variable "image_operating_system" {
  description = "OS for compute instances"
  type        = string
  default     = "Canonical Ubuntu"
}

variable "image_os_version" {
  description = "OS version"
  type        = string
  default     = "22.04"
}

# --- Block Storage ---
variable "app_block_volume_size_gb" {
  description = "Block volume size in GB for application data"
  type        = number
  default     = 50
}

variable "db_block_volume_size_gb" {
  description = "Block volume size in GB for PostgreSQL data"
  type        = number
  default     = 50
}

# --- SSH ---
variable "ssh_public_key_path" {
  description = "Path to the SSH public key (local execution)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_public_key" {
  description = "SSH public key contents (TFC remote execution; supersedes ssh_public_key_path)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_allowed_ip" {
  description = "IP address / CIDR allowed to SSH to instances"
  type        = string
  default     = "0.0.0.0/0"
}

# --- Application ---
variable "app_domain" {
  description = "Domain name for the expense management application"
  type        = string
  default     = "expense.example.com"
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret for authentication"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_api_key" {
  description = "Grafana Cloud API key for metrics remote write"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus remote write endpoint"
  type        = string
  default     = ""
}

# =============================================================================
# Child Module — expense-oci-infra/terraform/
# =============================================================================
module "expense_oci_infra" {
  source = "./terraform"

  # Authentication
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  oci_private_key  = var.oci_private_key
  oci_region       = var.oci_region

  # Networking
  vcn_cidr              = var.vcn_cidr
  public_subnet_app_cidr = var.public_subnet_app_cidr
  public_subnet_db_cidr  = var.public_subnet_db_cidr

  # Compute
  app_instance_shape    = var.app_instance_shape
  app_instance_ocpus    = var.app_instance_ocpus
  app_instance_memory_gb = var.app_instance_memory_gb
  db_instance_shape     = var.db_instance_shape
  db_instance_ocpus     = var.db_instance_ocpus
  db_instance_memory_gb = var.db_instance_memory_gb

  # OS Image
  image_operating_system = var.image_operating_system
  image_os_version       = var.image_os_version

  # Block Storage
  app_block_volume_size_gb = var.app_block_volume_size_gb
  db_block_volume_size_gb  = var.db_block_volume_size_gb

  # SSH
  ssh_public_key_path = var.ssh_public_key_path
  ssh_public_key      = var.ssh_public_key
  ssh_allowed_ip      = var.ssh_allowed_ip

  # Application
  app_domain                  = var.app_domain
  db_password                 = var.db_password
  jwt_secret                  = var.jwt_secret
  grafana_cloud_api_key       = var.grafana_cloud_api_key
  grafana_cloud_prometheus_url = var.grafana_cloud_prometheus_url
}

# =============================================================================
# Root-Level Outputs (pass-through from child module)
# =============================================================================
output "vcn_id" {
  description = "OCID of the VCN"
  value       = module.expense_oci_infra.vcn_id
}

output "app_subnet_id" {
  description = "OCID of the application subnet"
  value       = module.expense_oci_infra.app_subnet_id
}

output "db_subnet_id" {
  description = "OCID of the database subnet"
  value       = module.expense_oci_infra.db_subnet_id
}

output "app_instance_id" {
  description = "OCID of the application compute instance"
  value       = module.expense_oci_infra.app_instance_id
}

output "app_instance_public_ip" {
  description = "Public IP address of the application server"
  value       = module.expense_oci_infra.app_instance_public_ip
}

output "app_instance_private_ip" {
  description = "Private IP address of the application server"
  value       = module.expense_oci_infra.app_instance_private_ip
}

output "db_instance_id" {
  description = "OCID of the database compute instance"
  value       = module.expense_oci_infra.db_instance_id
}

output "db_instance_public_ip" {
  description = "Public IP address of the database server"
  value       = module.expense_oci_infra.db_instance_public_ip
}

output "db_instance_private_ip" {
  description = "Private IP address of the database server (use for app→db)"
  value       = module.expense_oci_infra.db_instance_private_ip
}

output "load_balancer_id" {
  description = "OCID of the load balancer"
  value       = module.expense_oci_infra.load_balancer_id
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = module.expense_oci_infra.load_balancer_public_ip
}

output "app_url" {
  description = "Application URL (configure your domain DNS A record to the LB IP)"
  value       = module.expense_oci_infra.app_url
}

output "ssh_app_command" {
  description = "SSH command to connect to the application server"
  value       = module.expense_oci_infra.ssh_app_command
}

output "ssh_db_command" {
  description = "SSH command to connect to the database server"
  value       = module.expense_oci_infra.ssh_db_command
}

output "post_setup_instructions" {
  description = "Instructions after Terraform apply completes"
  value       = module.expense_oci_infra.post_setup_instructions
}

# =============================================================================
# Debug Outputs — Authentication Configuration
# =============================================================================
# These outputs help diagnose authentication issues in Terraform Cloud
# =============================================================================

output "debug_auth_method" {
  description = "Which authentication method is being used (TFC or local file)"
  value       = module.expense_oci_infra.debug_auth_method
  sensitive   = true
}

output "debug_private_key_path" {
  description = "Expanded path to the private key file (for local execution)"
  value       = module.expense_oci_infra.debug_private_key_path
}

output "debug_oci_private_key_set" {
  description = "Whether oci_private_key variable is set (true/false)"
  value       = module.expense_oci_infra.debug_oci_private_key_set
  sensitive   = true
}

output "debug_tenancy_ocid_set" {
  description = "Whether tenancy_ocid is configured"
  value       = length(var.tenancy_ocid) > 0 ? "✓ SET" : "✗ NOT SET"
  sensitive   = true
}

output "debug_user_ocid_set" {
  description = "Whether user_ocid is configured"
  value       = length(var.user_ocid) > 0 ? "✓ SET" : "✗ NOT SET"
  sensitive   = true
}

output "debug_fingerprint_set" {
  description = "Whether fingerprint is configured"
  value       = length(var.fingerprint) > 0 ? "✓ SET" : "✗ NOT SET"
  sensitive   = true
}
