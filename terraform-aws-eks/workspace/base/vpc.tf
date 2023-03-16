data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
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

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.tags
}

