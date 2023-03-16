terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }

//  backend "s3" {
//    region  = "ap-southeast-1"
//    bucket  = "terraform-state-eks-main-t-01"
//    key     = "terraform.tfstate"
//    encrypt        = true
//    dynamodb_table = "terraform-eks-main-t-lock-3"
//  }
}

//resource "aws_s3_bucket" "tfstate" {
//  bucket = "terraform-state-${local.cluster_name}-003"
//  versioning {
//    enabled = true
//  }
//}
//
//resource "aws_s3_bucket_versioning" "tfstate" {
//  bucket = "terraform-state-${local.cluster_name}-003"
//  versioning_configuration {
//    status = "Enabled"
//  }
//}
//
//resource "aws_dynamodb_table" "terraform_state_lock" {
//  name           = "terraform-${local.cluster_name}-lock-3"
//  hash_key       = "LockID"
//  billing_mode   = "PAY_PER_REQUEST"
//  attribute {
//    name = "LockID"
//    type = "S"
//  }
//}
