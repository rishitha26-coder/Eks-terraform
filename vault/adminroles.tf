resource "vault_github_team" "devops-mogo" {
  backend  = "github"
  team     = "devops"
  policies = ["default", "admin"]
}

resource "vault_github_user" "mkroeze-mogo" {
  backend  = "github"
  user     = "mkroeze"
  policies = ["default", "tokenadmin","trade-token-service-policy"]
}

resource "vault_github_user" "ajoshi-moka-mogo" {
  backend  = "github"
  user     = "ajoshi-moka-mogo"
  policies = ["default", "tokenadmin","trade-token-service-policy"]
}

resource "vault_policy" "admin" {
  name = "admin"
  policy = file("${path.module}/admin-policy.hcl")
  }

resource "vault_policy" "mkroeze" {
  name = "mkroeze"
  policy = file("${path.module}/tokenadmin-policy.hcl")
  }

resource "vault_policy" "tokenadmin" {
  name = "tokenadmin"
  policy = file("${path.module}/tokenadmin-policy.hcl")
  }

#resource "vault_policy" "k8s" {
#  name = "k8s"
#  policy = "secret/k8s/*"
#  }
