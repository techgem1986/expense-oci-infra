# =============================================================================
# Local Backend Configuration
# =============================================================================
# Usage:
#   terraform init -backend-config=backend.local.hcl -reconfigure
# =============================================================================

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}