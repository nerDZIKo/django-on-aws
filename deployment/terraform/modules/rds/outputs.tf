# modules/rds/outputs.tf
output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_username" {
  description = "Database username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "db_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "db_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "db_secret_arn" {
  description = "ARN of the RDS credentials secret in Secrets Manager."
  value       = aws_secretsmanager_secret.db_credentials.arn
}