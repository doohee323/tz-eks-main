//resource "aws_security_group" "nsg_main_lb" {
//  name        = "${local.cluster_name}-${local.environment}-lb"
//  description = "Allow connections from external resources while limiting connections from ${local.cluster_name}-${local.environment}-lb to internal resources"
//  vpc_id      = module.vpc.vpc_id
//  tags        = local.tags
//}
//
//resource "aws_security_group" "nsg_main_task" {
//  name        = "${local.cluster_name}-${local.environment}-task"
//  description = "Limit connections from internal resources while allowing ${local.cluster_name}-${local.environment}-task to connect to all external resources"
//  vpc_id      = module.vpc.vpc_id
//  tags        = local.tags
//}
//
//# Rules for the LB (Targets the task SG)
//
//resource "aws_security_group_rule" "nsg_lb_main_egress_rule" {
//  description              = "Only allow SG ${local.cluster_name}-${local.environment}-lb to connect to ${local.cluster_name}-${local.environment}-task on port ${var.container_main_port}"
//  type                     = "egress"
//  from_port                = var.container_main_port
//  to_port                  = var.container_main_port
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.nsg_main_task.id
//  security_group_id = aws_security_group.nsg_main_lb.id
//}
//
//# Rules for the TASK (Targets the LB SG)
//resource "aws_security_group_rule" "nsg_task_main_ingress_rule" {
//  description              = "Only allow connections from SG ${local.cluster_name}-${local.environment}-lb on port ${var.container_main_port}"
//  type                     = "ingress"
//  from_port                = var.container_main_port
//  to_port                  = var.container_main_port
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.nsg_main_lb.id
//  security_group_id = aws_security_group.nsg_main_task.id
//}
//
//resource "aws_security_group_rule" "nsg_task_main_egress_rule" {
//  description = "Allows task to establish connections to all resources"
//  type        = "egress"
//  from_port   = "0"
//  to_port     = "0"
//  protocol    = "-1"
//  cidr_blocks = ["0.0.0.0/0"]
//  security_group_id = aws_security_group.nsg_main_task.id
//}
//
//# For bastions
//resource "aws_security_group" "eks-main-dev-bastion" {
//  vpc_id = module.vpc.vpc_id
//  name = "${local.cluster_name}_dev_bastion"
//  description = "${local.cluster_name} Dev Bastion Security Group"
//  ingress {
//    from_port   = 0
//    to_port     = 0
//    protocol    = "-1"
//    cidr_blocks = [local.VPC_CIDR, local.DEVOPS_UTIL_CIDR]
//  }
//  egress {
//    from_port   = 0
//    to_port     = 0
//    protocol    = "-1"
//    cidr_blocks = ["0.0.0.0/0"]
//  }
//  ##[ allow only for tz-eks-main's cidr_blocks ]######################################################
//  ingress {
//    from_port   = -1
//    to_port     = -1
//    protocol    = "icmp"
//    cidr_blocks = [local.VPC_CIDR, local.DEVOPS_UTIL_CIDR]
//  }
//  ingress {
//    from_port   = 22
//    to_port     = 22
//    protocol    = "tcp"
//    cidr_blocks = [local.VPC_CIDR, local.DEVOPS_UTIL_CIDR]
//  }
//  ingress {
//    from_port   = 80
//    to_port     = 80
//    protocol    = "tcp"
//    cidr_blocks = ["0.0.0.0/0"]
//  }
//  ingress {
//    from_port   = 443
//    to_port     = 443
//    protocol    = "tcp"
//    cidr_blocks = ["0.0.0.0/0"]
//  }
//  tags = {
//    Name = "${local.cluster_name} Dev Bastion Security Group"
//    Description = ""
//  }
//}
//
//resource "aws_security_group_rule" "eks-main-dev-bastion-ssh-from-all" {
//  description = "Allow all SSH connections"
//  type = "ingress"
//  from_port = "22"
//  to_port = "22"
//  protocol = "TCP"
////  cidr_blocks = local.allowed_management_cidr_blocks
//  cidr_blocks = ["0.0.0.0/0"]
//  security_group_id = aws_security_group.eks-main-dev-bastion.id
//}
