terraform {
  required_version = "1.9.7"
  backend "s3" {
    bucket = "fargate-example-terraform"
    key    = "develop.terraform.tfstate"
    region = "ap-northeast-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.59.0"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_elb_service_account" "main" {}

provider "aws" {
  region = local.region
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
  default_tags {
    tags = local.default_tags
  }
}

data "terraform_remote_state" "root" {
  backend = "s3"

  config = {
    bucket = local.tf_s3_bucket
    region = local.region
    key    = local.root_state_file
  }
}
