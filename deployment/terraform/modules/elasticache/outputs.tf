# modules/elasticache/outputs.tf
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_security_group_id" {
  description = "Security group ID for ElastiCache"
  value       = aws_security_group.elasticache.id
}