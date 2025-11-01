output "frontend_alb_dns" {
  value = aws_lb.frontend.dns_name
}

output "backend_alb_dns" {
  value = aws_lb.backend.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.this.address
}

output "secret_name" {
  value = aws_secretsmanager_secret.db.name
}
