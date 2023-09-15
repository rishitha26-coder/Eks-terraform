resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  set {
        name = "installCRDs"
        value = "false"
    }
  version = "v${var.cert-manager_version}"
  namespace  = "cert-manager"
  depends_on = [kubernetes_namespace.cert-manager, data.external.provision_crds ]
}
