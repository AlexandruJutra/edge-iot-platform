# ---------------------------------------------------------------------------
# Static website: private S3 bucket served through CloudFront (OAC).
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_acm_certificate" "website" {
  provider    = aws.us_east_1
  domain      = var.website_domain_name
  statuses    = ["ISSUED"]
  most_recent = true

  lifecycle {
    postcondition {
      condition     = self.arn == var.website_certificate_arn
      error_message = "The issued ACM certificate for the website domain does not match WEBSITE_CERTIFICATE_ARN."
    }
  }
}

data "aws_cloudfront_distribution" "website" {
  id = var.website_distribution_id
}

data "aws_cloudfront_origin_access_control" "website" {
  id = var.website_oac_id

  lifecycle {
    postcondition {
      condition = (
        self.origin_access_control_origin_type == "s3" &&
        self.signing_behavior == "always" &&
        self.signing_protocol == "sigv4"
      )
      error_message = "The website CloudFront OAC must use S3 origins, always sign requests, and use SigV4."
    }
  }
}

locals {
  index_html = templatefile("${path.module}/website/index.html.tftpl", {
    grafana_embed_url = var.grafana_embed_url
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

removed {
  from = aws_cloudfront_origin_access_control.website

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_cloudfront_distribution.website

  lifecycle {
    destroy = false
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
            "AWS:SourceArn" = data.aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

output "website_url" {
  description = "HTTPS URL of the custom website domain."
  value       = "https://${var.website_domain_name}"
}

output "website_bucket_name" {
  description = "S3 bucket that stores the static website files."
  value       = aws_s3_bucket.website.id
}
