# Define variables
variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "davidawcloudsecurity123"
}

variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
  default     = "us-east-1"
}

variable "env" {
  description = "The environment (e.g., Production, Development)"
  type        = string
  default     = "Production"
}

provider "aws" {
  region = var.region
}

# Step 1: Create the S3 bucket for static website hosting
resource "aws_s3_bucket" "static_website" {
  bucket = var.bucket_name

  tags = {
    Name        = "Static Website Bucket"
    Environment = var.env
  }
}

# Use the new website configuration resource
resource "aws_s3_bucket_website_configuration" "static_website_config" {
  bucket = aws_s3_bucket.static_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Use the dedicated ACL resource
resource "aws_s3_bucket_acl" "static_website_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.static_website]
  bucket     = aws_s3_bucket.static_website.id
  acl        = "private"
}

# Configure object ownership - keep only ONE instance of this resource
resource "aws_s3_bucket_ownership_controls" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Configure public access block settings - keep only ONE instance
resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.id
  
  block_public_acls       = false
  block_public_policy     = false  # Must be false to allow public bucket policy
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 bucket policy to allow public read access
resource "aws_s3_bucket_policy" "static_website_policy" {
  depends_on = [aws_s3_bucket_public_access_block.static_website]

  bucket = aws_s3_bucket.static_website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}

# Upload website files
resource "aws_s3_object" "index_html" {
  depends_on = [aws_s3_bucket.static_website]
  bucket     = aws_s3_bucket.static_website.id
  key        = "index.html"
  source     = "./public/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "error_html" {
  depends_on = [aws_s3_bucket.static_website]
  bucket     = aws_s3_bucket.static_website.id
  key        = "error.html"
  source     = "./public/error.html"
  content_type = "text/html"
}

# Upload assets folder
resource "null_resource" "s3_upload" {
  depends_on = [aws_s3_bucket.static_website]

  provisioner "local-exec" {
    command = "aws s3 cp ./public/assets s3://${aws_s3_bucket.static_website.bucket}/assets --recursive"
  }
}

# Clean up on destroy
resource "null_resource" "delete_objects" {
  depends_on = [aws_s3_bucket.static_website]

  triggers = {
    bucket_name = aws_s3_bucket.static_website.bucket
  }

  provisioner "local-exec" {
    command = "aws s3 rm s3://${self.triggers.bucket_name}/ --recursive"
    when    = destroy
  }
}

# Output the website URL
output "website_url" {
  value = "http://${aws_s3_bucket.static_website.bucket}.s3-website-${var.region}.amazonaws.com"
}
