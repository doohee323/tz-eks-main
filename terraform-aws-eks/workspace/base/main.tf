provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"

  cluster_name                    = local.name
  cluster_version                 = "1.24"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
//  cluster_endpoint_public_access_cidrs = ["118.33.104.1/32", "183.96.137.87/32", "98.42.152.117/32"]

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  create_kms_key = true
  cluster_encryption_config = {
    "resources": [
      "secrets"
    ]
  }
  kms_key_deletion_window_in_days = 7
  enable_kms_key_rotation         = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = [local.instance_type]

    attach_cluster_primary_security_group = false
    vpc_security_group_ids                = [aws_security_group.all_worker_mgmt.id]
  }

  eks_managed_node_groups = {
    devops = {
      min_size     = 1
      max_size     = 4
      desired_size = 3
      instance_types = [local.instance_type]
      subnets = [element(module.vpc.private_subnets, 0)]
      disk_size = 30
      labels = {
        team = "devops"
        environment = "prod"
      }
      update_config = {
        max_unavailable_percentage = 70 # or set `max_unavailable`
      }
      vpc_security_group_ids = [
        aws_security_group.worker_group_devops.id
      ]
    }
//    consul = {
//      min_size     = 0
//      max_size     = 2
//      desired_size = 1
//      instance_types = ["t3.medium"]
//      subnets = [element(module.vpc.private_subnets, 0)]
//      disk_size = 100
//      labels = {
//        team = "devops"
//        environment = "consul"
//      }
//      update_config = {
//        max_unavailable_percentage = 70
//      }
//      vpc_security_group_ids = [
//        aws_security_group.worker_group_devops.id
//      ]
//    }
  }

  cluster_identity_providers = {
    sts = {
      client_id = "sts.amazonaws.com"
    }
  }

  manage_aws_auth_configmap = true

  aws_auth_roles = local.aws_auth_roles

  aws_auth_users = local.aws_auth_users

  aws_auth_accounts = [
    var.account_id
  ]

  tags = local.tags
}

################################################################################
# Disabled creation
################################################################################
module "disabled_eks" {
  source  = "terraform-aws-modules/eks/aws"

  create = false
}

module "disabled_eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

  create = false
}

