resource "aws_route53_record" "api" {
  zone_id = data.terraform_remote_state.root.outputs.zone_id
  name    = "api.${local.domain}"
  type    = "A" # Aレコード（IPアドレスをドメイン名でエイリアス）

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "admin" {
  zone_id = data.terraform_remote_state.root.outputs.zone_id
  name    = local.admin_domain
  type    = "A" # Aレコード（CloudFrontディストリビューションをドメイン名でエイリアス）

  alias {
    name                   = aws_cloudfront_distribution.admin.domain_name
    zone_id                = aws_cloudfront_distribution.admin.hosted_zone_id
    evaluate_target_health = false
  }
}

# おまけ
# CNAMEレコード（ドメイン名を別のドメイン名でエイリアス）
