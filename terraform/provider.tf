# =============================================================================
# OCI Provider Configuration — Child Module
# =============================================================================
# This is a child module (sourced from ../main.tf).  The root module
# declares the actual provider {} block and passes in all variable values.
#
# This file declares only the required_providers so Terraform knows which
# providers this module needs, and the Always Free Tier reference.
# =============================================================================
# OCI Always Free Tier supports:
#   - 2 AMD Micro instances (1/8 OCPU, 1GB RAM each)
#   - Up to 4 OCPUs ARM Ampere A1 (24GB total RAM)
#   - 2 Block Volumes (100GB total)
#   - 10GB Object Storage
#   - 1 Flexible Load Balancer (10Mbps)
#   - Autonomous Database (2 instances, 20GB each) - Oracle only, not PostgreSQL
# =============================================================================

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
}
