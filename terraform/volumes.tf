# =============================================================================
# OCI Block Volumes
# =============================================================================
# Always Free Tier: 2 block volumes, 100GB total
#   - App volume (50GB): Docker data, container volumes, logs
#   - DB volume  (50GB): PostgreSQL data directory, Redis AOF/RDB files
#
# Both volumes configured as VPU 10 (Balanced, free tier)
# Attached via iSCSI and auto-mounted by cloud-init
# =============================================================================

# ---------------------------------------------------------------------------
# App Server Block Volume
# ---------------------------------------------------------------------------
resource "oci_core_volume" "app_volume" {
  compartment_id      = data.oci_identity_compartment.root.id
  availability_domain = local.availability_domain_names[local.app_ad_index]
  display_name        = "expense-app-data-volume"
  size_in_gbs         = var.app_block_volume_size_gb
  vpus_per_gb         = 10 # Balanced (free tier)

  freeform_tags = merge(local.common_tags, {
    AttachedTo = "expense-app-server"
    Purpose    = "docker-data"
  })
}

resource "oci_core_volume_attachment" "app_volume_attach" {
  attachment_type = "iscsi"
  compartment_id  = data.oci_identity_compartment.root.id
  instance_id     = oci_core_instance.app_instance.id
  volume_id       = oci_core_volume.app_volume.id
  device          = "/dev/oracleoci/oraclevdb"
  display_name    = "expense-app-volume-attachment"
}

# ---------------------------------------------------------------------------
# DB Server Block Volume
# ---------------------------------------------------------------------------
resource "oci_core_volume" "db_volume" {
  compartment_id      = data.oci_identity_compartment.root.id
  availability_domain = local.availability_domain_names[local.db_ad_index]
  display_name        = "expense-db-data-volume"
  size_in_gbs         = var.db_block_volume_size_gb
  vpus_per_gb         = 10 # Balanced (free tier)

  freeform_tags = merge(local.common_tags, {
    AttachedTo = "expense-db-server"
    Purpose    = "postgresql-redis-data"
  })
}

resource "oci_core_volume_attachment" "db_volume_attach" {
  attachment_type = "iscsi"
  compartment_id  = data.oci_identity_compartment.root.id
  instance_id     = oci_core_instance.db_instance.id
  volume_id       = oci_core_volume.db_volume.id
  device          = "/dev/oracleoci/oraclevdb"
  display_name    = "expense-db-volume-attachment"
}

# =============================================================================
# Outputs for Volume iSCSI Commands (used by cloud-init)
# =============================================================================
output "app_volume_iscsi_commands" {
  description = "iSCSI attach commands for the app volume"
  value       = oci_core_volume_attachment.app_volume_attach.iscsi_login_state
  sensitive   = false
}

output "db_volume_iscsi_commands" {
  description = "iSCSI attach commands for the DB volume"
  value       = oci_core_volume_attachment.db_volume_attach.iscsi_login_state
  sensitive   = false
}