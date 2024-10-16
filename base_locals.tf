locals {
  project         = "fargate-example"
  region          = "ap-northeast-1"
  tf_s3_bucket    = "fargate-example-terraform"
  root_state_file = "terraform.tfstate"
  base_domain     = "fargate-example.com"
  default_tags = {
    Managed     = "terraform"
    Project     = local.project
    Environment = local.env
    Repository  = local.repository
  }
}
