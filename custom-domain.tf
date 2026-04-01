###############################################################################
# Custom Domain – SFTP
###############################################################################
resource "aws_transfer_tag" "sftp_custom_hostname" {
  count = try(var.custom_domain.sftp_hostname, null) != null ? 1 : 0

  resource_arn = aws_transfer_server.sftp.arn
  key          = "aws:transfer:customHostname"
  value        = var.custom_domain.sftp_hostname
}

###############################################################################
# Custom Domain – Web App (CloudFront distribution)
###############################################################################
resource "aws_cloudfront_distribution" "web_app" {
  count = var.enable_web_app && try(var.custom_domain.web_app_hostname, null) != null ? 1 : 0

  enabled = true
  aliases = [var.custom_domain.web_app_hostname]

  origin {
    domain_name = replace(aws_transfer_web_app.this[0].access_endpoint, "https://", "")
    origin_id   = "transfer-web-app"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "transfer-web-app"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.custom_domain.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = var.tags
}
