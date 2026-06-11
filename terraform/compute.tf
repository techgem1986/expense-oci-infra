# =============================================================================
# OCI Compute - ARM Ampere A1 Instances
# =============================================================================
# Design:
#   - 2 instances (app + database) running on ARM Ampere A1 (Always Free)
#   - Each instance: 2 OCPU, 12GB RAM (total: 4 OCPU / 24GB — max free tier)
#   - App instance collocates: Docker Compose (Spring Boot backend + Nginx frontend)
#   - DB instance collocates: PostgreSQL 15 + Redis 7
#   - Instances in separate ADs for resilience
#   - Cloud-init for automated bootstrap
# =============================================================================

# ---------------------------------------------------------------------------
# Local values for SSH key resolution
# ---------------------------------------------------------------------------
# Supports two modes:
#   Local:    Uses var.ssh_public_key_path via file() function
#   TFC:      Uses var.ssh_public_key directly (PEM content)
# ---------------------------------------------------------------------------
locals {
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : try(file(pathexpand(var.ssh_public_key_path)), "")
}

# ---------------------------------------------------------------------------
# App Instance - Runs Backend + Frontend via Docker Compose
# ---------------------------------------------------------------------------
resource "oci_core_instance" "app_instance" {
  compartment_id      = data.oci_identity_compartment.root.id
  availability_domain = local.availability_domain_names[local.app_ad_index]
  shape               = var.app_instance_shape
  display_name        = "expense-app-server"

  shape_config {
    ocpus         = var.app_instance_ocpus
    memory_in_gbs = var.app_instance_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.app_subnet.id
    display_name     = "expense-app-vnic"
    hostname_label   = "expense-app"
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/app-cloud-init.yaml", {
      db_private_ip     = oci_core_instance.db_instance.private_ip
      db_password       = var.db_password
      jwt_secret        = var.jwt_secret
      app_domain        = var.app_domain
      grafana_cloud_url = var.grafana_cloud_prometheus_url
      grafana_cloud_key = var.grafana_cloud_api_key
    }))
  }

  freeform_tags = merge(local.common_tags, {
    Role = "application"
  })

  depends_on = [oci_core_instance.db_instance]
}

# ---------------------------------------------------------------------------
# DB Instance - Runs PostgreSQL + Redis
# ---------------------------------------------------------------------------
resource "oci_core_instance" "db_instance" {
  compartment_id      = data.oci_identity_compartment.root.id
  availability_domain = local.availability_domain_names[local.db_ad_index]
  shape               = var.db_instance_shape
  display_name        = "expense-db-server"

  shape_config {
    ocpus         = var.db_instance_ocpus
    memory_in_gbs = var.db_instance_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.db_subnet.id
    display_name     = "expense-db-vnic"
    hostname_label   = "expense-db"
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/db-cloud-init.yaml", {
      db_password = var.db_password
    }))
  }

  freeform_tags = merge(local.common_tags, {
    Role = "database"
  })
}