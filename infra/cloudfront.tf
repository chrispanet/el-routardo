# Distribution existante (d1bedazj92888q.cloudfront.net), importée.
# Après le premier `terraform plan`, aligner ce fichier sur infra/discovery/cloudfront.json
# pour que le plan ne montre que les changements voulus.

locals {
  s3_origin_id = "s3-${var.site_bucket_name}"
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "el-routardo-site"
  description                       = "Accès CloudFront au bucket du site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "El Routardo (guide Palma)"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2and3"

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Politique gérée "CachingOptimized"
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # Une clé S3 absente renvoie 403 (bucket privé) : on l'expose comme un 404 propre.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/index.html"
    error_caching_min_ttl = 60
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
