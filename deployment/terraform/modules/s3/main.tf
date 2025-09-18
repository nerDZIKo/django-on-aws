# modules/s3/main.tf

# S3 Bucket for static files
resource "aws_s3_bucket" "static_files" {
  bucket = "${var.project_name}-${var.environment}-static-files"

  tags = {
    Name        = "${var.project_name}-${var.environment}-static-files"
    Environment = var.environment
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "static_files" {
  bucket = aws_s3_bucket.static_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket policy for public read access to static files
resource "aws_s3_bucket_policy" "static_files" {
  bucket = aws_s3_bucket.static_files.id
  depends_on = [aws_s3_bucket_public_access_block.static_files]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_files.arn}/*"
      }
    ]
  })
}

# S3 Bucket for media files
resource "aws_s3_bucket" "media_files" {
  bucket = "${var.project_name}-${var.environment}-media-files"

  tags = {
    Name        = "${var.project_name}-${var.environment}-media-files"
    Environment = var.environment
  }
}

# S3 Bucket versioning for media files
resource "aws_s3_bucket_versioning" "media_files" {
  bucket = aws_s3_bucket.media_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption for media files
resource "aws_s3_bucket_server_side_encryption_configuration" "media_files" {
  bucket = aws_s3_bucket.media_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block for media files
resource "aws_s3_bucket_public_access_block" "media_files" {
  bucket = aws_s3_bucket.media_files.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket policy for public read access to media files
resource "aws_s3_bucket_policy" "media_files" {
  bucket = aws_s3_bucket.media_files.id
  depends_on = [aws_s3_bucket_public_access_block.media_files]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.media_files.arn}/*"
      }
    ]
  })
}

# S3 Bucket for backups (private)
resource "aws_s3_bucket" "backups" {
  bucket = "${var.project_name}-${var.environment}-backups"

  tags = {
    Name        = "${var.project_name}-${var.environment}-backups"
    Environment = var.environment
  }
}

# S3 Bucket versioning for backups
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption for backups
resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block for backups (keep private)
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# modules/s3/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}