resource "vault_auth_backend" "kubernetes" {
    type = "kubernetes"
  }

resource "vault_kubernetes_auth_backend_config" "local-cluster" {
  backend = vault_auth_backend.kubernetes.path
  kubernetes_host = var.eks_endpoint
  kubernetes_ca_cert = var.eks_cluster_ca
  token_reviewer_jwt = var.vault_eks_token
  }  

resource "vault_kubernetes_auth_backend_role" "trade" {
  role_name = "trade"
  bound_service_account_names = ["Stonks-api-taskdefinitionTaskRole"]
  bound_service_account_namespaces = ["trade*", "production", "qa"]
  token_policies = ["trade"]
  token_ttl = 3600
  depends_on = [ vault_kubernetes_auth_backend_config.local-cluster ]
  }

resource "vault_policy" "k8s-default" {
  name = "k8s-default"
  policy = file("${path.module}/k8s-default-policy.hcl")
  }

resource "vault_mount" "k8s-default" {
  path = "secrets/k8s/default/kv"
  type = "kv-v2"
  description = "Secrets for the kubernetes backend"
  }

resource "vault_policy" "k8s-soa" {
  name = "k8s-soa"
  policy = file("${path.module}/k8s-soa-policy.hcl")
  }

resource "vault_mount" "k8s-soa" {
  path = "secrets/k8s/soa/kv"
  type = "kv-v2"
  description = "Secrets for the kubernetes backend"
  }

resource "vault_policy" "k8s-trade" {
  name = "k8s-trade"
  policy = file("${path.module}/k8s-trade-policy.hcl")
  }

resource "vault_mount" "k8s-trade" {
  path = "secrets/k8s/trade/kv"
  type = "kv-v2"
  description = "Secrets for the kubernetes backend trade namespace"
  }
