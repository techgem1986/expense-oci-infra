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
# OCI Provider
# ---------------------------------------------------------------------------
# Local execution:  var.oci_private_key stays "" → uses var.private_key_path
# TFC execution:    var.oci_private_key holds PEM content → supersedes path
# ---------------------------------------------------------------------------
provider "oci" {
  region           = var.oci_region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = var.oci_private_key != "" ? var.oci_private_key : null
  private_key_path = var.oci_private_key == "" ? var.private_key_path : null
}
