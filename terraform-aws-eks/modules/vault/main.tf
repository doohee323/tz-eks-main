terraform {
  required_providers {
    shell = {
      source = "scottwinkler/shell"
      version = "1.7.7"
    }
  }
}

resource "shell_script" "vault-secrets" {
  lifecycle_commands {
    create = file("${path.module}/scripts/upsert.sh")
    update = file("${path.module}/scripts/upsert.sh")
    read   = file("${path.module}/scripts/read.sh")
    delete = file("${path.module}/scripts/delete.sh")
  }

  sensitive_environment = {
    MUTABLE_SECRETS = jsonencode(var.mutable_secrets)
    IMMUTABLE_SECRETS = jsonencode(var.immutable_secrets)
  }
  environment = {
    TARGET_SECRET_PATH = var.path
  }
}
