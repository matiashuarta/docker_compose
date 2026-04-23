# outputs.tf: values printed to your terminal after terraform apply completes
# think of these as the "results" of your deployment
# you'd copy these URLs to test your app or configure monitoring

# the public URL of your frontend — this is what you'd open in a browser
# it's the DNS name AWS automatically assigns to the load balancer
output "frontend_url" {
  description = "Public URL for the frontend"
  value       = "http://${aws_lb.frontend.dns_name}"
}

# the internal URL of the backend ALB
# this is NOT accessible from the internet — only from inside the VPC
# useful to know for debugging or if you want to call it from another internal service
output "backend_url" {
  description = "Internal URL for the backend (only reachable inside VPC)"
  value       = "http://${aws_lb.backend.dns_name}"
}

# the hostname of the RDS Postgres instance
# format: docker-compose-app-db.xxxxxxxxx.us-east-1.rds.amazonaws.com
# useful if you ever want to connect to the DB directly (e.g. via a bastion host or VPN)
output "rds_endpoint" {
  description = "RDS Postgres host address"
  value       = aws_db_instance.postgres.address
}
