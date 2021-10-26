provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}
