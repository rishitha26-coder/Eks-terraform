provider "vault" {
  address = var.vault_url
  token = var.vault_root_token
  }

terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "3.0.1"
    }
  }
}

