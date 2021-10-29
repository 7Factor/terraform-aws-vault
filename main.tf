# Required terraform version
terraform {
  required_version = ">=0.12.3"
}

# Grab the current region to be used everywhere
data "aws_region" "current" {}

data "aws_ami" "base_ami" {
  most_recent = true
  owners      = [137112412989]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

# grab the caller identity to use the account_id
data "aws_caller_identity" "current" {}
