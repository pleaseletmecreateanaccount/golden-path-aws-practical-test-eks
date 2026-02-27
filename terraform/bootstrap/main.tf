##############################################################################
# Bootstrap: Creates S3 + DynamoDB for Terraform remote state.
# Run ONCE before `terraform apply` in environments/production.
# Uses local state (committed to .gitignore — or managed manually).
##############################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region"     { default = "ap-southeast-1" }
variable "aws_account_id" { default = "825566110381" }
variable "project"        { default = "golden-path" }

# ─── S3 State Bucket ─────────────────────────────────────────────────────────
resource "aws_s3_bucket" "tfstate" {
  bucket        = "${var.project}-tfstate-${var.aws_account_id}"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── DynamoDB Lock Table ──────────────────────────────────────────────────────
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${var.project}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "s3_bucket_name"       { value = aws_s3_bucket.tfstate.id }
output "dynamodb_table_name"  { value = aws_dynamodb_table.tfstate_lock.name }
