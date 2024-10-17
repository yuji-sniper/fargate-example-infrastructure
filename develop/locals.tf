locals {
  env = "develop"
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
  ]

  domain         = "dev.${local.base_domain}"
  admin_domain   = "admin.${local.domain}"
}
