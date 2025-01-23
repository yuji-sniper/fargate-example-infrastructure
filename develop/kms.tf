resource "aws_kms_key" "application" {
  description         = "${local.project}-${local.env}-application"
  enable_key_rotation = true
}
