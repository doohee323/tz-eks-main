locals {
  cluster_name                  = var.cluster_name
  name                          = local.cluster_name
  region                        = var.region
  environment                   = var.environment
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"
  tzcorp_zone_id               = var.tzcorp_zone_id
  tags                          = {
    application: local.cluster_name,
    environment: local.environment,
  }
  VCP_BCLASS = var.VCP_BCLASS
  VPC_CIDR   = "${local.VCP_BCLASS}.0.0/16"
  instance_type = var.instance_type
  DEVOPS_UTIL_CIDR = var.DEVOPS_UTIL_CIDR
  EKS_EXTERNAL_IP = var.EKS_EXTERNAL_IP
  JENKINS_IP = var.JENKINS_IP

  allowed_management_cidr_blocks = [
    local.VPC_CIDR,
    local.DEVOPS_UTIL_CIDR,
    local.JENKINS_IP,
    local.EKS_EXTERNAL_IP
  ]

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${var.account_id}:role/${local.cluster_name}-k8sAdmin"
      username = "devops"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::${var.account_id}:role/${local.cluster_name}-k8sAdmin"
      username = "doohee323"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::${var.account_id}:role/${local.cluster_name}-k8sDev"
      username = "doogee323"
      groups   = ["system:basic-user"]
    },
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${var.account_id}:user/devops"
      username = "devops"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::${var.account_id}:user/adminuser"
      username = "adminuser"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::${var.account_id}:user/doohee323"
      username = "doohee323"
      groups   = ["system:masters"]
    }
  ]

}
