variable "account_id" {
}
variable "cluster_name" {
}
variable "region" {
  default = "us-west-1"
}
variable "environment" {
  default = "prod"
}
variable "tzcorp_zone_id" {
  default = "ZEGN8MOW1060B"
}
variable "VCP_BCLASS" {
  default = "10.50"
}
variable "instance_type" {
  default = "t3.medium"
}
variable "DEVOPS_UTIL_CIDR" {
  default = "10.10.0.0/16"
}
variable "EKS_EXTERNAL_IP" {
  default = "3.37.171.13/32"
}
variable "JENKINS_IP" {
  default = "3.35.170.100/32"
}

variable "INSTANCE_DEVICE_NAME" {
  default = "/dev/xvdh"     # nvme1n1  xvdh
}

variable "kms_key_arn" {
  default     = ""
  description = "KMS key ARN to use if you want to encrypt EKS node root volumes"
  type        = string
}

variable "container_main_port" {
  default = "31000"
}

# The port the load balancer will listen on
variable "lb_main_port" {
  default = "80"
}

# The load balancer protocol
variable "lb_main_protocol" {
  default = "HTTP"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = [
    "746446553436",
  ]
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      rolearn  = "arn:aws:iam::746446553436:role/eks-main-t20221104030123224500000002"
      username = "eks-main-t20221104030123224500000002"
      groups   = ["system:masters"]
    },
  ]
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      userarn  = "arn:aws:iam::746446553436:user/devops"
      username = "devops"
      groups   = ["system:masters"]
    }
  ]
}

variable "allowed_management_cidr_blocks" {
  default = [
  ]
}
