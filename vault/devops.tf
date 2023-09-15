resource "vault_policy" "artifactory" {
  name = "artifactory"
  policy = file("${path.module}/artifactory-policy.hcl")
  }

resource "vault_mount" "devops-kv" {
  path = "secrets/devops/kv"
  type = "kv-v2"
  description = "Secrets for the devops and pipelines backend"
  }

resource "vault_mount" "devops-sensitive" {
  path = "secrets/devops/sensitive"
  type = "kv-v2"
  description = "Secrets for the devops admins only"
  }

resource "vault_approle_auth_backend_role" "artifactory-nonprod" {
  backend        = "devops"
  role_name      = "artifactory-nonprod"
  token_policies = [ "artifactory-nonprod" ]
  token_ttl     = 600
  token_max_ttl = 3600
  depends_on = [ vault_auth_backend.devops ]
}
resource "vault_auth_backend" "devops" {
  type = "approle"
  path = "devops"
}

