# =============================================================================
# OCI Flexible Load Balancer (Always Free: 10 Mbps)
# =============================================================================
# Configures a public load balancer that:
#   1. Terminates TLS/SSL at the LB
#   2. Routes HTTP (80) → redirect to HTTPS (443)
#   3. Routes HTTPS (443) → backend app server:80 (Nginx serving frontend, proxying API)
#   4. Health checks against backend:80/
#
# Nginx on the app server handles:
#   - /            → Static frontend files
#   - /api/*       → Proxy to localhost:8080 (Spring Boot)
# =============================================================================

# ---------------------------------------------------------------------------
# Load Balancer
# ---------------------------------------------------------------------------
resource "oci_load_balancer" "expense_lb" {
  compartment_id = data.oci_identity_compartment.root.id
  display_name   = "expense-load-balancer"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.app_subnet.id]
  is_private     = false

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }

  freeform_tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Backend Set - HTTP (port 80 on app server)
# ---------------------------------------------------------------------------
resource "oci_load_balancer_backend_set" "http_backend_set" {
  load_balancer_id = oci_load_balancer.expense_lb.id
  name             = "expense-http-backend"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = 80
    url_path          = "/"
    return_code       = 200
    retries           = 3
    timeout_in_millis = 3000
    interval_ms       = 10000
  }
}

# ---------------------------------------------------------------------------
# Backend - App Server
# ---------------------------------------------------------------------------
resource "oci_load_balancer_backend" "app_backend" {
  load_balancer_id = oci_load_balancer.expense_lb.id
  backendset_name  = oci_load_balancer_backend_set.http_backend_set.name
  ip_address       = oci_core_instance.app_instance.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

# ---------------------------------------------------------------------------
# Listener - HTTP (port 80) → Redirect to HTTPS
# ---------------------------------------------------------------------------
resource "oci_load_balancer_listener" "http_listener" {
  load_balancer_id         = oci_load_balancer.expense_lb.id
  name                     = "expense-http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.http_backend_set.name
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}

# ---------------------------------------------------------------------------
# Listener - HTTPS (port 443) with SSL
# =============================================================================
# NOTE: TLS/SSL certificate management:
#
# For full TLS, you need a certificate. Options within Always Free:
#   1. Manually upload a free Let's Encrypt certificate
#   2. Use certbot on the app instance with HTTP challenge (set up domain DNS first)
#   3. OCI Certificate service (not always free)
#
# RECOMMENDED APPROACH (free + automated):
#   - Use Let's Encrypt via certbot on the app server
#   - Run certbot on the app server, not on the LB
#   - LB passes through HTTPS → backend (HTTPS-terminate at Nginx)
#   OR
#   - Use ACME DNS challenge with OCI DNS (if domain is managed by OCI DNS)
#
# For initial deployment, we create only the HTTP listener. Once the domain
# DNS is configured and certbot obtains a certificate, add the HTTPS listener
# manually or via a second `terraform apply`.
# =============================================================================
#
# Uncomment the block below once you have a valid SSL certificate OCID:
#
# resource "oci_load_balancer_listener" "https_listener" {
#   load_balancer_id         = oci_load_balancer.expense_lb.id
#   name                     = "expense-https-listener"
#   default_backend_set_name = oci_load_balancer_backend_set.http_backend_set.name
#   port                     = 443
#   protocol                 = "HTTP"
#
#   ssl_configuration {
#     certificate_name        = "expense-app-cert"
#     verify_peer_certificate = false
#     verify_depth            = 0
#   }
#
#   connection_configuration {
#     idle_timeout_in_seconds = 60
#   }
# }
# =============================================================================