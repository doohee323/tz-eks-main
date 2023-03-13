resource "aws_key_pair" "main" {
  public_key      = file("./${local.cluster_name}.pub")
  key_name = local.cluster_name
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_kms_key" "eks-main-vault-kms" {
  description             = "Vault unseal key"
  tags = {
    Name = "${local.cluster_name}-vault-kms-unseal"
  }
}

resource "aws_kms_alias" "eks-main-vault-kms" {
  name          = "alias/${local.cluster_name}-vault-kms-unseal_02"
  target_key_id = aws_kms_key.eks-main-vault-kms.key_id
}

