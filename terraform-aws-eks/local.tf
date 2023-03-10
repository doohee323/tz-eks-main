locals {

  kubeconfig_name = var.kubeconfig_name == "" ? "eks_${var.cluster_name}" : var.kubeconfig_name

  kubeconfig = var.create ? templatefile("${path.module}/templates/kubeconfig.tpl", {
    kubeconfig_name                   = local.kubeconfig_name
    endpoint                          = coalescelist(aws_eks_cluster.this[*].endpoint, [""])[0]
    cluster_auth_base64               = coalescelist(aws_eks_cluster.this[*].certificate_authority[0].data, [""])[0]
    aws_authenticator_command         = var.kubeconfig_aws_authenticator_command
    aws_authenticator_command_args    = length(var.kubeconfig_aws_authenticator_command_args) > 0 ? var.kubeconfig_aws_authenticator_command_args : ["token", "-i", coalescelist(aws_eks_cluster.this[*].name, [""])[0]]
    aws_authenticator_additional_args = var.kubeconfig_aws_authenticator_additional_args
    aws_authenticator_env_variables   = var.kubeconfig_aws_authenticator_env_variables
  }) : ""
}
