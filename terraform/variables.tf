# =============================================================================
# OCI Provider Variables - Authentication
# =============================================================================

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
  description = "Path to the API signing private key (used for local execution, ignored when oci_private_key is set)"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "oci_private_key" {
  description = "OCI API signing private key PEM content (used for Terraform Cloud remote execution, supersedes private_key_path)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "oci_region" {
  description = "OCI region identifier"
  type        = string
  default     = "ap-hyderabad-1"
}

# =============================================================================
# Networking
# =============================================================================

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

# =============================================================================
# Compute
# =============================================================================
# AMD Micro Always Free: VM.Standard.E2.1.Micro (1 OCPU, 1GB RAM, x86)
# This shape has better availability than ARM Ampere A1 in some regions.
# Limitation: 1 OCPU / 1GB is minimal — tune Docker containers accordingly.
# ---------------------------------------------------------------------------
# If you need more resources, switch back to VM.Standard.A1.Flex (ARM, 2 OCPU / 12GB)
# but be aware of capacity constraints in certain regions (e.g., ap-hyderabad-1).
# =============================================================================

variable "app_instance_shape" {
  description = "Compute shape for the application server (AMD Micro Always Free)"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "app_instance_ocpus" {
  description = "Number of OCPUs for the application server (fixed for Micro shape, kept for compatibility)"
  type        = number
  default     = 1
}

variable "app_instance_memory_gb" {
  description = "Memory in GB for the application server (fixed for Micro shape, kept for compatibility)"
  type        = number
  default     = 1
}

variable "db_instance_shape" {
  description = "Compute shape for the database server (AMD Micro Always Free)"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "db_instance_ocpus" {
  description = "Number of OCPUs for the database server (fixed for Micro shape, kept for compatibility)"
  type        = number
  default     = 1
}

variable "db_instance_memory_gb" {
  description = "Memory in GB for the database server (fixed for Micro shape, kept for compatibility)"
  type        = number
  default     = 1
}

# =============================================================================
# Operating System Image
# =============================================================================

variable "image_operating_system" {
  description = "OS for compute instances"
  type        = string
  default     = "Canonical Ubuntu"
}

variable "image_os_version" {
  description = "OS version"
  type        = string
  default     = "24.04"
}

# =============================================================================
# Block Storage (Always Free: 2 volumes, 100GB total)
# =============================================================================

variable "app_block_volume_size_gb" {
  description = "Block volume size in GB for application data (docker volumes, logs)"
  type        = number
  default     = 50
}

variable "db_block_volume_size_gb" {
  description = "Block volume size in GB for PostgreSQL data directory"
  type        = number
  default     = 50
}

# =============================================================================
# SSH Access
# =============================================================================

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for instance access (used for local execution)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_public_key" {
  description = "SSH public key contents (used for Terraform Cloud remote execution, supersedes ssh_public_key_path)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_allowed_ip" {
  description = "IP address/CIDR allowed to SSH to instances (your office/home IP)"
  type        = string
  default     = "0.0.0.0/0"
  sensitive   = false
}

# =============================================================================
# Application
# =============================================================================

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