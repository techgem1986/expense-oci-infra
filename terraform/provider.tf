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
  using_tfc_private_key      = var.oci_private_key != ""
  private_key_path_expanded = pathexpand(var.private_key_path)

  # Determine which private key to use.
  # On TFC (remote execution) var.oci_private_key must be set in workspace variables.
  # On local execution the key is read from private_key_path on disk.
  # We use try() so that if the file doesn't exist we fall back to an empty string
  # rather than a hard error, then validate below.
  oci_api_private_key = var.oci_private_key != "" ? var.oci_private_key : try(file(local.private_key_path_expanded), "")

  # ------------------------------------------------------------------
  # Pre-condition: a non-empty private key MUST be provided through
  #                 one of the two supported methods.
  # ------------------------------------------------------------------
  _check_private_key = regex(
    "^(-----BEGIN [A-Z ]*PRIVATE KEY-----)",
    local.oci_api_private_key
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
