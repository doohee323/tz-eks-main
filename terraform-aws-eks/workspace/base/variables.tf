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
  default = "Z02506481727V529IYA6J"
}
variable "VCP_BCLASS" {
  default = "10.20"
}
variable "instance_type" {
  default = "t3.small"
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

variable "lb_main_port" {
  default = "80"
}

variable "lb_main_protocol" {
  default = "HTTP"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = [
    "472304975363",
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
      rolearn  = "arn:aws:iam::472304975363:role/eks-main-t20221104030123224500000002"
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
      userarn  = "arn:aws:iam::472304975363:user/devops"
      username = "devops"
      groups   = ["system:masters"]
    }
  ]
}

variable "allowed_management_cidr_blocks" {
  default = [
  ]
}
