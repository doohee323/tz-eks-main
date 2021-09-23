#------------------------------------------------------------------------------#
# Key pair
#------------------------------------------------------------------------------#

# Performs 'ImportKeyPair' API operation (not 'CreateKeyPair')
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
    Name = "vault-kms-unseal-${local.cluster_name}"
  }
}

resource "aws_kms_alias" "eks-main-vault-kms" {
  name          = "alias/${local.cluster_name}-vault-kms-unseal"
  target_key_id = aws_kms_key.eks-main-vault-kms.key_id
}

