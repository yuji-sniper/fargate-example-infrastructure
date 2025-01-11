# ===============================================================================
# CloudFront Distribution assets
# ===============================================================================
resource "aws_cloudfront_distribution" "assets" {
  origin {
    domain_name              = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.assets.bucket
    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "${local.project}-${local.env}-assets"
  http_version        = "http2and3"
  default_root_object = "index.html"

  aliases = [local.domain]

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate.naked.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  ordered_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]
    cached_methods = [
      "GET",
      "HEAD",
    ]
    path_pattern               = "/favicon.ico"
    smooth_streaming           = false
    target_origin_id           = aws_s3_bucket.assets.bucket
    trusted_signers            = []
    viewer_protocol_policy     = "redirect-to-https" # http -> https
    cache_policy_id            = aws_cloudfront_cache_policy.assets.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.assets.id
  }

  ordered_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]
    cached_methods = [
      "GET",
      "HEAD",
    ]
    path_pattern               = "/manifest.json"
    smooth_streaming           = false
    target_origin_id           = aws_s3_bucket.assets.bucket
    trusted_signers            = []
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = aws_cloudfront_cache_policy.assets.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.assets.id
  }

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]
    cached_methods = [
      "GET",
      "HEAD",
    ]
    smooth_streaming           = false
    target_origin_id           = aws_s3_bucket.assets.bucket
    trusted_signers            = []
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = aws_cloudfront_cache_policy.assets.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.assets.id

    # メンテナンス入れる時はこれを有効に
    # function_association {
    #   event_type   = "viewer-request"
    #   function_arn = aws_cloudfront_function.maintenance_mode.arn
    # }

    # IP制限
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.check_ip.arn
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "assets/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_caching_min_ttl = 60
    error_code            = 403
    response_code         = 403
    response_page_path    = "/index.html"
  }
  custom_error_response {
    error_caching_min_ttl = 60
    error_code            = 404
    response_code         = 404
    response_page_path    = "/index.html"
  }
}

# ===============================================================================
# CloudFront Distribution admin
# ===============================================================================
resource "aws_cloudfront_distribution" "admin" {
  origin {
    domain_name              = aws_s3_bucket.admin.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.admin.bucket
    origin_access_control_id = aws_cloudfront_origin_access_control.admin.id
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "${local.project}-${local.env}-admin"
  http_version        = "http2and3"
  default_root_object = "index.html"

  aliases = [local.admin_domain]

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate.admin.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]
    cached_methods = [
      "GET",
      "HEAD",
    ]
    smooth_streaming           = false
    target_origin_id           = aws_s3_bucket.admin.bucket
    trusted_signers            = []
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = aws_cloudfront_cache_policy.assets.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.assets.id

    # IP制限
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.check_ip.arn
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "admin/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_caching_min_ttl = 60
    error_code            = 403
    response_code         = 403
    response_page_path    = "/index.html"
  }
  custom_error_response {
    error_caching_min_ttl = 60
    error_code            = 404
    response_code         = 404
    response_page_path    = "/index.html"
  }
}

# ===============================================================================
# Origin Access Control
# ===============================================================================
resource "aws_cloudfront_origin_access_control" "admin" {
  name                              = "${local.project}-${local.env}-web-admin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFrontからのみアクセス可能にする
resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "${local.project}-${local.env}-web-assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ===============================================================================
# CloudFront Function
# ===============================================================================

# resource "aws_cloudfront_function" "maintenance_mode" {
#   name    = "${local.project}-${local.env}-maintenance-mode"
#   runtime = "cloudfront-js-1.0"
#   comment = "${local.project}-${local.env}-maintenance-mode"
#   publish = true
#   code    = file("${path.module}/files/cloudfront_functions/maintenance_mode/index.js")
# }

resource "aws_cloudfront_function" "check_ip" {
  name    = "${local.project}-${local.env}-check-ip"
  runtime = "cloudfront-js-1.0"
  comment = "${local.project}-${local.env}-check-ip"
  publish = true
  code = templatefile(
    "${path.module}/files/cloudfront_functions/check_ip/index.js",
    {
      ip_list = jsonencode(flatten([
        for ip in local.cloudfront_allow_ips :
        ([
          for n in range(pow(2, 32 - split("/", ip)[1])) :
          cidrhost(ip, n)
        ])
      ]))
    }
  )
}

locals {
  cloudfront_allow_ips = flatten([
    local.ips,
  ])
}

# ===============================================================================
# CloudFront Response Header Policy
# ===============================================================================
resource "aws_cloudfront_response_headers_policy" "assets" {
  name = "${local.project}-${local.env}-response-header-policy-assets"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }
    referrer_policy {
      override        = true
      referrer_policy = "strict-origin-when-cross-origin"
    }
    # HSTS（Strict-Transport-Security）は、HTTPSを強制する
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }
    xss_protection {
      mode_block = false
      override   = false
      protection = true
    }
  }

  # remove_headers_config {
  #   items {
  #     header = "Server"
  #   }
  # }
}

# ===============================================================================
# CloudFront Cache Policy for assets
# ===============================================================================
resource "aws_cloudfront_cache_policy" "assets" {
  name        = "${local.project}-${local.env}-cache-policy-assets"
  comment     = "CloudFront Cache Policy for assets"
  default_ttl = 300
  max_ttl     = 600
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}
