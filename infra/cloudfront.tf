# Distribution existante (d1bedazj92888q.cloudfront.net), importée.
# Aligné sur la configuration réelle relevée le 2026-09-15 (scripts/discover.sh).

locals {
  s3_origin_id = "s3-site"
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "elroutardo-oac"
  description                       = "Managed by Terraform"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = false
  comment             = "El Routardo - Guide Palma"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2"

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Configuration héritée (pas de cache policy) : conservée telle quelle.
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
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
