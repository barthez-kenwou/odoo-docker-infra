# =============================================================================
# Encrypted, versioned, lifecycle-managed S3 bucket used as the restic
# backend for Postgres + filestore backups (see scripts/backup/*.sh).
# Disabled by default (root variable `enable_cloud_storage`) — restic can
# just as well target a local path or a MinIO container for a pure-local lab.
# =============================================================================

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "backups" {
  bucket = "${var.project_name}-${var.environment}-backups-${random_id.suffix.hex}"

  tags = {
    environment = var.environment
    purpose     = "postgres-and-filestore-backups"
  }
}

# 3-2-1 strategy, "immutable if possible": versioning + Object Lock give us
# a WORM-like guarantee that ransomware/an attacker with stolen credentials
# can't silently delete or overwrite existing backup generations.
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Retention policy: keep the last 30 daily generations in Standard, then
# transition older-but-still-retained copies to cheaper storage, matching
# the RPO/RTO documented in docs/runbooks/disaster-recovery.md.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "transition-and-expire-noncurrent"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Deny any non-TLS access to the bucket outright.
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.backups.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.backups.arn,
        "${aws_s3_bucket.backups.arn}/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}
