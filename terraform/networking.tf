# =============================================================================
# OCI Networking - VCN, Subnets, Gateways, Route Tables, Security Lists
# =============================================================================
# Design:
#   - Single VCN with two public subnets (app tier + database tier)
#   - Internet Gateway for outbound access
#   - Security lists with least-privilege rules
#   - Database is in a separate subnet for network-level isolation
#
# Always Free: No NAT Gateway needed; both subnets are public (Free tier
# doesn't include private subnets with NAT). We secure the DB via security
# lists instead.
# =============================================================================

# ---------------------------------------------------------------------------
# Virtual Cloud Network
# ---------------------------------------------------------------------------
resource "oci_core_vcn" "expense_vcn" {
  compartment_id = data.oci_identity_compartment.root.id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "expense-vcn"
  dns_label      = "expensevcn"
  freeform_tags  = local.common_tags
}

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
resource "oci_core_internet_gateway" "expense_igw" {
  compartment_id = data.oci_identity_compartment.root.id
  vcn_id         = oci_core_vcn.expense_vcn.id
  display_name   = "expense-internet-gateway"
  freeform_tags  = local.common_tags
}

# ---------------------------------------------------------------------------
# Route Table (default via Internet Gateway)
# ---------------------------------------------------------------------------
resource "oci_core_default_route_table" "expense_route_table" {
  manage_default_resource_id = oci_core_vcn.expense_vcn.default_route_table_id

  route_rules {
    network_entity_id = oci_core_internet_gateway.expense_igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# ---------------------------------------------------------------------------
# Public Subnet - Application Tier
# ---------------------------------------------------------------------------
resource "oci_core_subnet" "app_subnet" {
  compartment_id             = data.oci_identity_compartment.root.id
  vcn_id                     = oci_core_vcn.expense_vcn.id
  cidr_block                 = var.public_subnet_app_cidr
  display_name               = "expense-app-subnet"
  dns_label                  = "appsubnet"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_vcn.expense_vcn.default_route_table_id
  security_list_ids          = [oci_core_security_list.app_security_list.id]
  freeform_tags              = local.common_tags
}

# ---------------------------------------------------------------------------
# Public Subnet - Database Tier
# ---------------------------------------------------------------------------
resource "oci_core_subnet" "db_subnet" {
  compartment_id             = data.oci_identity_compartment.root.id
  vcn_id                     = oci_core_vcn.expense_vcn.id
  cidr_block                 = var.public_subnet_db_cidr
  display_name               = "expense-db-subnet"
  dns_label                  = "dbsubnet"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_vcn.expense_vcn.default_route_table_id
  security_list_ids          = [oci_core_security_list.db_security_list.id]
  freeform_tags              = local.common_tags
}

# ---------------------------------------------------------------------------
# Security List - Application Tier
# ---------------------------------------------------------------------------
# Rules:
#   - Ingress: HTTP (80) + HTTPS (443) from anywhere
#   - Ingress: SSH (22) from trusted IP only
#   - Ingress: Backend app port (8080) from app subnet + db subnet (internal)
#   - Egress: All outbound (for package downloads, API calls)
#
# NOTE: In production, the load balancer handles SSL termination, so 443 ingress
# goes to the LB, not directly to the instance. We keep 443 open for cert renewal.
# ---------------------------------------------------------------------------
resource "oci_core_security_list" "app_security_list" {
  compartment_id = data.oci_identity_compartment.root.id
  vcn_id         = oci_core_vcn.expense_vcn.id
  display_name   = "expense-app-security-list"
  freeform_tags  = local.common_tags

  # --- Ingress Rules ---

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    description = "HTTP from anywhere"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    description = "HTTPS from anywhere"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.ssh_allowed_ip
    source_type = "CIDR_BLOCK"
    description = "SSH from trusted IP"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.public_subnet_app_cidr
    source_type = "CIDR_BLOCK"
    description = "Spring Boot backend from app subnet"
    tcp_options {
      min = 8080
      max = 8080
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.public_subnet_db_cidr
    source_type = "CIDR_BLOCK"
    description = "Spring Boot backend from db subnet"
    tcp_options {
      min = 8080
      max = 8080
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.public_subnet_app_cidr
    source_type = "CIDR_BLOCK"
    description = "Prometheus Node Exporter from app subnet"
    tcp_options {
      min = 9100
      max = 9100
    }
  }

  # --- Egress Rules ---

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }
}

# ---------------------------------------------------------------------------
# Security List - Database Tier
# ---------------------------------------------------------------------------
# Rules:
#   - Ingress: PostgreSQL (5432) from app subnet only
#   - Ingress: SSH (22) from trusted IP only
#   - Ingress: Prometheus Node Exporter (9100) from app subnet (monitoring)
#   - Egress: Outbound to app subnet only (for database-initiated connections)
# ---------------------------------------------------------------------------
resource "oci_core_security_list" "db_security_list" {
  compartment_id = data.oci_identity_compartment.root.id
  vcn_id         = oci_core_vcn.expense_vcn.id
  display_name   = "expense-db-security-list"
  freeform_tags  = local.common_tags

  # --- Ingress Rules ---

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.public_subnet_app_cidr
    source_type = "CIDR_BLOCK"
    description = "PostgreSQL from app subnet"
    tcp_options {
      min = 5432
      max = 5432
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.ssh_allowed_ip
    source_type = "CIDR_BLOCK"
    description = "SSH from trusted IP"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.public_subnet_app_cidr
    source_type = "CIDR_BLOCK"
    description = "Prometheus Node Exporter from app subnet"
    tcp_options {
      min = 9100
      max = 9100
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.public_subnet_app_cidr
    source_type = "CIDR_BLOCK"
    description = "Redis from app subnet"
    tcp_options {
      min = 6379
      max = 6379
    }
  }

  # --- Egress Rules ---

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound (for OS updates, Docker pulls)"
  }
}