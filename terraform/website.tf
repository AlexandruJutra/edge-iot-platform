# ---------------------------------------------------------------------------
# Static website: private S3 bucket served through CloudFront (OAC).
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

locals {
  index_html = templatefile("${path.module}/website/index.html.tftpl", {
    grafana_embed_url  = var.grafana_embed_url
    telemetry_api_url = "${aws_apigatewayv2_stage.grafana_json_export.invoke_url}/telemetry"
  })
}

resource "aws_s3_bucket" "website" {
  bucket        = "${var.project_name}-website-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = local.index_html
  content_type = "text/html"
  etag         = md5(local.index_html)
}

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.project_name}-website-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = "${var.project_name} static website"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-website"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

output "website_url" {
  description = "HTTPS URL of the CloudFront-served static website."
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "website_bucket_name" {
  description = "S3 bucket that stores the static website files."
  value       = aws_s3_bucket.website.id
}
