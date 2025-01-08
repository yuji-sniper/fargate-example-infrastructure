# ===============================================================================
# api
# ===============================================================================
# APIドメインのSSL/TLS証明書を作成
resource "aws_acm_certificate" "api" {
  domain_name       = "api.${local.domain}"
  validation_method = "DNS"
  tags = {
    Name = local.domain
  }
}

# APIドメインのSSL/TLS証明書の検証用レコードを作成
## Aレコード（IPアドレスをドメイン名でエイリアス）
resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for i in aws_acm_certificate.api.domain_validation_options : i.domain_name => {
      name   = i.resource_record_name
      record = i.resource_record_value
      type   = i.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  ttl     = 300
  type    = each.value.type # CNAME（ドメイン名を別のドメイン名にエイリアス）
  zone_id = data.terraform_remote_state.root.outputs.zone_id
}

# APIドメインのDNSレコードをチェックして証明書の検証
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.api_cert_validation : record.fqdn]
}

# ===============================================================================
# admin
# ===============================================================================
resource "aws_acm_certificate" "admin" {
  domain_name       = local.admin_domain
  validation_method = "DNS"
  provider          = aws.virginia

  tags = {
    Name = local.domain
  }
}

resource "aws_route53_record" "admin_cert_validation" {
  for_each = {
    for i in aws_acm_certificate.admin.domain_validation_options : i.domain_name => {
      name   = i.resource_record_name
      record = i.resource_record_value
      type   = i.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  ttl     = 300
  type    = each.value.type
  zone_id = data.terraform_remote_state.root.outputs.zone_id
}

resource "aws_acm_certificate_validation" "admin" {
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.admin.arn
  validation_record_fqdns = [for record in aws_route53_record.admin_cert_validation : record.fqdn]
}
