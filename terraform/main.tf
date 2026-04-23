# terraform block: defines the configuration for Terraform itself (not AWS resources)
terraform {

  # required_providers: tells Terraform which plugins to download
  # without this, Terraform wouldn't know how to talk to AWS
  required_providers {
    aws = {
      source  = "hashicorp/aws"   # official AWS plugin maintained by HashiCorp
      version = "~> 5.0"          # use any 5.x version (e.g. 5.1, 5.99) but NOT 6.0
    }
  }
}

# provider block: configures the AWS plugin with your settings
# this is what authenticates with your AWS account using the credentials from `aws configure`
provider "aws" {
  region = var.aws_region  # us-east-1 — defined in variables.tf
}
