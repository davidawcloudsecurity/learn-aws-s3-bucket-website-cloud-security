# Define variables
variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "davidawcloudsecurity123"  # Default bucket name
}

variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
  default     = "us-east-1"  # Default AWS region
}

variable "env" {
  description = "The environment (e.g., Production, Development)"
  type        = string
  default     = "Production"  # Default environment
}

provider "aws" {
  region = var.region
}

# Step 1: Create the S3 bucket for static website hosting
resource "aws_s3_bucket" "static_website" {
  bucket = var.bucket_name
  acl    = "private"  # ACL set to private to avoid conflicts with Object Ownership

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags = {
    Name        = "Static Website Bucket"
    Environment = var.env
  }
}

resource "aws_s3_bucket_ownership_controls" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Step 1: Set account-level public access block settings for S3
resource "aws_s3_account_public_access_block" "account_block_public_access" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# Step 2: Block public access to the bucket using aws_s3_bucket_public_access_block
resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Step 3: Upload website files from GitHub (locally downloaded files)
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.static_website.bucket
  key    = "index.html"
  source = "./public/index.html"  # Local path to index.html
  # Removed acl to avoid ACL conflict
}

resource "aws_s3_object" "error_html" {
  bucket = aws_s3_bucket.static_website.bucket
  key    = "error.html"
  source = "./public/error.html"  # Local path to error.html
  # Removed acl to avoid ACL conflict
}

# Step 4: Null resource to upload local files from the "public" folder to S3
resource "null_resource" "s3_upload" {
  depends_on = [aws_s3_bucket.static_website]

  provisioner "local-exec" {
    command = "aws s3 cp ./public/assets s3://${aws_s3_bucket.static_website.bucket}/assets --recursive"

    # include if using outside of cloudshell
    # environment = {
    #  AWS_PROFILE = "your-aws-profile"  # Optionally, specify your AWS CLI profile if not using the default
    #}
  }
  # Ensure null_resource gets executed when running terraform destroy
  lifecycle {
    prevent_destroy = false
  }
}

# Step 4: Null resource to delete all objects inside the S3 bucket before deletion (only on destroy)
resource "null_resource" "delete_objects" {
  depends_on = [aws_s3_bucket.static_website]

  provisioner "local-exec" {
    command = "aws s3 rm s3://${aws_s3_bucket.static_website.bucket}/ --recursive"
    
    when = destroy  # Ensure this only runs during terraform destroy
  }

  triggers = {
    bucket_name = aws_s3_bucket.static_website.bucket
  }

  lifecycle {
    prevent_destroy = false  # Allow destruction of the resource
  }
}

# Optional: Enable versioning on the bucket (Uncomment if versioning is needed)
# resource "aws_s3_bucket_versioning" "versioning" {
#   bucket = aws_s3_bucket.static_website.bucket
# 
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# Optional: Enable logging (Specify a logging bucket if needed)
# resource "aws_s3_bucket_logging" "logging" {
#   bucket = aws_s3_bucket.static_website.bucket
# 
#   logging {
#     target_bucket = "your-logging-bucket-name"  # Replace with your logging bucket name
#     target_prefix = "logs/"
#   }
# }

# Optional: Set up CloudFront distribution for the website (recommended for performance)
# resource "aws_cloudfront_distribution" "static_website" {
#   origin {
#     domain_name = aws_s3_bucket.static_website.website_endpoint
#     origin_id   = "S3-${aws_s3_bucket.static_website.bucket}"
# 
#     s3_origin_config {
#       origin_access_identity = "origin-access-identity/cloudfront/your-identity-id"  # Optional for private access
#     }
#   }
# 
#   enabled = true
#   is_ipv6_enabled = true
#   comment = "CloudFront Distribution for Static Website"
# 
#   default_cache_behavior {
#     target_origin_id = "S3-${aws_s3_bucket.static_website.bucket}"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods = ["GET", "HEAD"]
#     forwarded_values {
#       query_string = false
#       cookies {
#         forward = "none"
#       }
#     }
#   }
# 
#   price_class = "PriceClass_100"  # Low-cost option (US, Canada, Europe)
#   
#   # SSL certificate for HTTPS (you can request one from ACM)
#   viewer_certificate {
#     acm_certificate_arn = "your-certificate-arn"  # Replace with your ACM certificate ARN
#     ssl_support_method   = "sni-only"
#   }
# 
#   # Optional: Logging for CloudFront
#   logging_config {
#     include_cookies = false
#     bucket          = "your-cloudfront-logs-bucket"
#     prefix          = "cloudfront-logs/"
#   }
# }

# Step 4: Output the static website URL (S3 endpoint)
output "website_url" {
  value = "http://${aws_s3_bucket.static_website.bucket}.s3-website-${var.region}.amazonaws.com"
}

# Optional: Output CloudFront URL (uncomment if using CloudFront)
# output "cloudfront_url" {
#   value = "https://${aws_cloudfront_distribution.static_website.domain_name}"  # If using CloudFront
# }
