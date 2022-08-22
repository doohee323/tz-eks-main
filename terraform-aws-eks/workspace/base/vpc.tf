data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "2.64.0"
  name                 = "${local.cluster_name}-vpc"
  cidr                 = local.VPC_CIDR
  azs                  = data.aws_availability_zones.available.names
  private_subnets = [
      for i in range(1, 10):
        "${local.VCP_BCLASS}.${i}.0/24"
  ]
  public_subnets = [
      for i in range(100, 110):
        "${local.VCP_BCLASS}.${i}.0/24"
  ]
//  private_subnets      = ["${local.VCP_BCLASS}.1.0/24", "${local.VCP_BCLASS}.2.0/24", "${local.VCP_BCLASS}.3.0/24"]
//  public_subnets       = ["${local.VCP_BCLASS}.4.0/24", "${local.VCP_BCLASS}.5.0/24", "${local.VCP_BCLASS}.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

