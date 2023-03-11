//resource "aws_s3_bucket" "terraform-state-eks-main" {
//  bucket = "terraform-state-${local.cluster_name}-1001"
//  tags = {
//    Name = "Terraform state"
//  }
//}

resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}
