resource "aws_security_group" "worker_group_devops" {
  name_prefix = "worker_group_devops"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.allowed_management_cidr_blocks
  }
  ##[ allow icmp only for the cidr_blocks ]######################################################
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [
      local.VPC_CIDR,
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {   # consul
    from_port = 8500
    to_port   = 8500
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {   # vault
    from_port = 8200
    to_port   = 8200
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_mgmt"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.allowed_management_cidr_blocks
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.VPC_CIDR]
  }
  ##[ allow icmp only for the cidr_blocks ]######################################################
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [
      local.VPC_CIDR,
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {   # consul
    from_port = 8500
    to_port   = 8500
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
  ingress {   # vault
    from_port = 8200
    to_port   = 8200
    protocol  = "tcp"
    cidr_blocks = [
      local.DEVOPS_UTIL_CIDR,
    ]
  }
}
