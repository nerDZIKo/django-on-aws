# modules/s3/outputs.tf
output "static_files_bucket_name" {
  description = "Name of the static files S3 bucket"
  value       = aws_s3_bucket.static_files.bucket
}

output "static_files_bucket_arn" {
  description = "ARN of the static files S3 bucket"
  value       = aws_s3_bucket.static_files.arn
}

output "static_files_bucket_domain_name" {
  description = "Domain name of the static files S3 bucket"
  value       = aws_s3_bucket.static_files.bucket_domain_name
}

output "media_files_bucket_name" {
  description = "Name of the media files S3 bucket"
  value       = aws_s3_bucket.media_files.bucket
}

output "media_files_bucket_arn" {
  description = "ARN of the media files S3 bucket"
  value       = aws_s3_bucket.media_files.arn
}

output "backups_bucket_name" {
  description = "Name of the backups S3 bucket"
  value       = aws_s3_bucket.backups.bucket
}

output "backups_bucket_arn" {
  description = "ARN of the backups S3 bucket"
  value       = aws_s3_bucket.backups.arn
}