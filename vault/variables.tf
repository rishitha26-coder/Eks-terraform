variable "vault_root_token" {
  description = "Root token for vault installation"
  type = string
  sensitive = true
  }

variable "vault_url" {
  description = "Vault URL to hit"
  type = string
  }


variable "eks_cluster_ca" {
  description = "EKS Cluster CA cert"
  type = string
  }


variable "eks_endpoint" {
  description = "EKS Endpoint URL"
  type = string
  }


variable "vault_eks_token" {
  description = "Vault EKS Token"
  type = string
  }
