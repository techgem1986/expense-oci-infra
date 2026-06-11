# =============================================================================
# OCI Provider Configuration — Child Module
# =============================================================================
# This is a child module (sourced from ../main.tf via module block).
# The root module declares required_providers and passes variable values.
#
# This file declares the provider "oci" block (which resolves module vars)
# and the required_providers stanza.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Local — Resolve OCI private key (TFC content vs local file path)
# ---------------------------------------------------------------------------
# The OCI provider only accepts one of private_key or private_key_path
# (not both, not null).  When oci_private_key is set (TFC / CI env),
# use it directly.  Otherwise read the key from local file path.
# This follows the pattern from https://github.com/oracle/terraform-provider-oci
# ---------------------------------------------------------------------------
locals {
  # Debug: Check which authentication method is being used
  using_tfc_private_key = var.oci_private_key != ""
  private_key_path_expanded = pathexpand(var.private_key_path)
  
  # Determine which private key to use
  oci_api_private_key = var.oci_private_key != "" ? var.oci_private_key : file(local.private_key_path_expanded)
  
  # Validate that we have a private key
  validate_private_key = (
    length(local.oci_api_private_key) > 0 
    ? true 
    : file("ERROR: No OCI private key provided. Set either oci_private_key variable (for TFC) or ensure private_key_path file exists (for local execution)")
  )
}

# ---------------------------------------------------------------------------
# OCI Provider
# ---------------------------------------------------------------------------
provider "oci" {
  region       = var.oci_region
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = local.oci_api_private_key
}
