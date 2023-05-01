resource "aws_key_pair" "main" {
  public_key      = file("./${local.cluster_name}.pub")
  key_name = local.cluster_name
  lifecycle {
    ignore_changes = [public_key]
  }
}
