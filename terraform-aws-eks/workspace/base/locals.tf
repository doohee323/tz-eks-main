locals {
  cluster_name                  = "eks-main"
  region                        = "ap-northeast-2"
  environment                   =  "dev"
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"
  tzcorp_zone_id               = "xxxxxxxxx"
  tags                          = {
    application: local.cluster_name,
    environment: local.environment,
    service: "web",
    team: "devops"
  }
  VCP_BCLASS = "10.20"
  VPC_CIDR   = "${local.VCP_BCLASS}.0.0/16"
  instance_type = "t3.medium"
  DEVOPS_UTIL_CIDR = "20.10.0.0/16"

  allowed_management_cidr_blocks = [
    // Main Office
    "10.1.1.100/32",
    local.VPC_CIDR,
    local.DEVOPS_UTIL_CIDR
  ]

  map_roles = [
    {
      rolearn  = "arn:aws:iam::xxxxxxxxxxxxx:role/eks-main20210422235638613200000002"
      username = "eks-main20210422235638613200000002"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::xxxxxxxxxxxxx:role/eks-main-k8sAdmin"
      username = "doohee.hong"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::xxxxxxxxxxxxx:role/eks-main-k8sDev"
      username = "developer"
      groups   = ["system:basic-user"]
    },
    {
      rolearn  = "arn:aws:iam::xxxxxxxxxxxxx:role/eks-main-k8sDev"
      username = "doogee.hong"
      groups   = ["system:basic-user"]
    }
  ]

  map_users = [
    {
      userarn  = "arn:aws:iam::xxxxxxxxxxxxx:user/devops"
      username = "devops"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::xxxxxxxxxxxxx:user/adminuser"
      username = "adminuser"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::xxxxxxxxxxxxx:user/doohee.hong"
      username = "doohee.hong"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::xxxxxxxxxxxxx:user/doogee.hong"
      username = "doogee.hong"
      groups   = ["system:masters"]
    }
  ]

}
