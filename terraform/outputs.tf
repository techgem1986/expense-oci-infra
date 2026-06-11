# =============================================================================
# Terraform Outputs
# =============================================================================

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.expense_vcn.id
}

output "app_subnet_id" {
  description = "OCID of the application subnet"
  value       = oci_core_subnet.app_subnet.id
}

output "db_subnet_id" {
  description = "OCID of the database subnet"
  value       = oci_core_subnet.db_subnet.id
}

output "app_instance_id" {
  description = "OCID of the application compute instance"
  value       = oci_core_instance.app_instance.id
}

output "app_instance_public_ip" {
  description = "Public IP address of the application server"
  value       = oci_core_instance.app_instance.public_ip
}

output "app_instance_private_ip" {
  description = "Private IP address of the application server"
  value       = oci_core_instance.app_instance.private_ip
}

output "db_instance_id" {
  description = "OCID of the database compute instance"
  value       = oci_core_instance.db_instance.id
}

output "db_instance_public_ip" {
  description = "Public IP address of the database server"
  value       = oci_core_instance.db_instance.public_ip
}

output "db_instance_private_ip" {
  description = "Private IP address of the database server (use this for app→db connections)"
  value       = oci_core_instance.db_instance.private_ip
}

output "load_balancer_id" {
  description = "OCID of the load balancer"
  value       = oci_load_balancer.expense_lb.id
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = oci_load_balancer.expense_lb.ip_address_details[0].ip_address
}

output "app_url" {
  description = "Application URL (configure your domain DNS A record to point to the LB IP)"
  value       = "http://${oci_load_balancer.expense_lb.ip_address_details[0].ip_address}"
}

output "ssh_app_command" {
  description = "SSH command to connect to the application server"
  value       = "ssh ubuntu@${oci_core_instance.app_instance.public_ip}"
}

output "ssh_db_command" {
  description = "SSH command to connect to the database server"
  value       = "ssh ubuntu@${oci_core_instance.db_instance.public_ip}"
}

output "post_setup_instructions" {
  description = "Instructions after Terraform apply completes"
  value = [
    "================================================================================",
    "✅ Infrastructure provisioned successfully!",
    "",
    "📋 NEXT STEPS:",
    "1. Wait 3-5 minutes for cloud-init to finish bootstrapping both instances.",
    "2. SSH into the app server:   ssh ubuntu@${oci_core_instance.app_instance.public_ip}",
    "3. SSH into the DB server:    ssh ubuntu@${oci_core_instance.db_instance.public_ip}",
    "4. Check cloud-init status:   tail -f /var/log/cloud-init-output.log",
    "5. Check Docker containers on app:  docker compose -f /opt/expense-app/docker-compose.prod.yml ps",
    "6. Check PostgreSQL on DB:    docker compose -f /opt/expense-db/docker-compose.yml ps",
    "7. Configure your DNS A record:  ${var.app_domain} → ${oci_load_balancer.expense_lb.ip_address_details[0].ip_address}",
    "8. Access the app:            http://${var.app_domain}",
    "9. Set up SSL (see docs/DEPLOYMENT.md SSL section):",
    "   - Run certbot on app server for Let's Encrypt",
    "   - Or upload a certificate to the OCI LB",
    "================================================================================",
  ]
}