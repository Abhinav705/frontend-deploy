terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.48.0"
    }
  }
  backend "s3" {
    bucket = "abhinak.fun-remote-state"
    key    = "expense-dev-backend" #can be any name
    region = "us-east-1"
    dynamodb_table = "abhinavk.fun-remote-state" #name is defined in dynamodb table
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}