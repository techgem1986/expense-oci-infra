# =============================================================================
# Terraform Cloud Backend Configuration (Remote Backend)
# =============================================================================
# This is passed via -backend-config flag at terraform init.
# The file must contain a backend block (without terraform { } wrapper).
# See: https://developer.hashicorp.com/terraform/language/settings/backends/configuration#file
#
# Usage:
#   terraform init -backend-config=backend.tfc.hcl -reconfigure
#
# Workspace type: CLI-driven workflow with "Local" execution mode
# =============================================================================

backend "remote" {
  organization = "expense-management"

  workspaces {
    name = "expense-management-oci"
  }
}
