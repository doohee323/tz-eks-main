resource "aws_s3_bucket" "terraform-state-eks-main" {
  bucket = "terraform-state-${local.cluster_name}-${random_string.random.result}"
  acl    = "private"

  tags = {
    Name = "Terraform state"
  }
}

resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_s3_bucket" "devops-grafana-backup" {
  bucket = "devops-grafana-${local.cluster_name}"
  acl    = "private"
  tags = {
    Name = "devops-grafana"
  }
}

resource "aws_s3_bucket" "devops-consul-backup" {
  bucket = "devops-consul-${local.cluster_name}"
  acl    = "private"
  tags = {
    Name = "devops-consul"
  }
}

resource "aws_s3_bucket" "devops-es-backup" {
  bucket = "devops-es-${local.cluster_name}"
  acl    = "private"
  tags = {
    Name = "devops-es"
  }
}

resource "aws_s3_bucket" "devops-thanos" {
  bucket = "devops-thanos-${local.cluster_name}"
  acl    = "public-read-write"
  tags = {
    Name = "devops-thanos"
  }
}
