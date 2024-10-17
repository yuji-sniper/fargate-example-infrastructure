terraform {
  required_version = "1.9.7"
  backend "s3" {
    bucket = "fargate-example-terraform"
    key    = "terraform.tfstate"
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
