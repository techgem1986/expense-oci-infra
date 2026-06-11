# =============================================================================
# OCI Data Sources - Compartment, Availability Domains, Images
# =============================================================================

# ---------------------------------------------------------------------------
# Root Compartment (uses the tenancy OCID)
# ---------------------------------------------------------------------------
data "oci_identity_compartment" "root" {
  id = var.tenancy_ocid
}

# ---------------------------------------------------------------------------
# Availability Domains (for multi-AD resilience)
# ---------------------------------------------------------------------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = data.oci_identity_compartment.root.id
}

# ---------------------------------------------------------------------------
# Oracle Linux / Ubuntu Image (Always Free compatible ARM image)
# ---------------------------------------------------------------------------
data "oci_core_images" "ubuntu_images" {
  compartment_id           = data.oci_identity_compartment.root.id
  operating_system         = var.image_operating_system
  operating_system_version = var.image_os_version
  shape                    = var.app_instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

# ---------------------------------------------------------------------------
# Local Values
# ---------------------------------------------------------------------------
locals {
  availability_domain_names = data.oci_identity_availability_domains.ads.availability_domains[*].name

  # Distribute instances across ADs:
  #   - App instance → AD 1
  #   - DB instance  → AD 2 (if available, else AD 1)
  app_ad_index = 0
  db_ad_index  = length(local.availability_domain_names) > 1 ? 1 : 0

  common_tags = {
    Project     = "Expense Management System"
    ManagedBy   = "Terraform"
    Environment = "Production"
    CostCenter  = "Personal"
    AlwaysFree  = "true"
  }

  # OS image OCID from the most recent available image
  image_id = data.oci_core_images.ubuntu_images.images[0].id
}