resource "aws_security_group" "nsg_main_lb" {
  name        = "${local.cluster_name}-${local.environment}-lb"
  description = "Allow connections from external resources while limiting connections from ${local.cluster_name}-${local.environment}-lb to internal resources"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
}

resource "aws_security_group" "nsg_main_task" {
  name        = "${local.cluster_name}-${local.environment}-task"
  description = "Limit connections from internal resources while allowing ${local.cluster_name}-${local.environment}-task to connect to all external resources"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
}

# Rules for the LB (Targets the task SG)

resource "aws_security_group_rule" "nsg_lb_main_egress_rule" {
  description              = "Only allow SG ${local.cluster_name}-${local.environment}-lb to connect to ${local.cluster_name}-${local.environment}-task on port ${var.container_main_port}"
  type                     = "egress"
  from_port                = var.container_main_port
  to_port                  = var.container_main_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nsg_main_task.id
  security_group_id = aws_security_group.nsg_main_lb.id
}

# Rules for the TASK (Targets the LB SG)
resource "aws_security_group_rule" "nsg_task_main_ingress_rule" {
  description              = "Only allow connections from SG ${local.cluster_name}-${local.environment}-lb on port ${var.container_main_port}"
  type                     = "ingress"
  from_port                = var.container_main_port
  to_port                  = var.container_main_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nsg_main_lb.id
  security_group_id = aws_security_group.nsg_main_task.id
}

resource "aws_security_group_rule" "nsg_task_main_egress_rule" {
  description = "Allows task to establish connections to all resources"
  type        = "egress"
  from_port   = "0"
  to_port     = "0"
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nsg_main_task.id
}

