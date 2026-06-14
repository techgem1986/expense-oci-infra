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
      version = "~> 8.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# ---------------------------------------------------------------------------
# Local — Resolve the private key path for the OCI provider
# ---------------------------------------------------------------------------
# The OCI provider requires either private_key (PEM string) or private_key_path.
#
# On Terraform Cloud (remote execution):
#   The OCI signing key PEM is provided via the sensitive variable
#   `oci_private_key`.  We write it to a temporary file via local_file so
#   the provider can read it via private_key_path.
#
# On local execution:
#   The PEM file is read from `private_key_path` (default ~/.oci/oci_api_key.pem).
#   The `oci_private_key` variable remains empty / default.
#
# This approach avoids the OCI provider init failure caused by passing an
# empty or badly formatted string to the `private_key` argument.
# ---------------------------------------------------------------------------
locals {
  # Debug: Check which authentication method is being used
  using_tfc_private_key      = var.oci_private_key != ""
  private_key_path_expanded = pathexpand(var.private_key_path)
}

# When oci_private_key is set (TFC/CI), write it to a temp file so we can
# use private_key_path instead of private_key (avoids provider init errors).
resource "local_file" "oci_api_key" {
  count    = local.using_tfc_private_key ? 1 : 0
  content  = var.oci_private_key
  filename = "${path.module}/.oci_api_key.pem"
}

# ---------------------------------------------------------------------------
# OCI Provider
# ---------------------------------------------------------------------------
provider "oci" {
  region           = var.oci_region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = local.using_tfc_private_key ? local_file.oci_api_key[0].filename : local.private_key_path_expanded
}