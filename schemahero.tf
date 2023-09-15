resource "kubernetes_namespace" "schemahero" {
  metadata {
    name = "schemahero"
  }
}

resource "helm_release" "schemahero" {
  name       = "schemahero"
  chart = "https://github.com/schemahero/schemahero-helm/archive/refs/tags/${var.schemahero-chart_version}.tar.gz"
  version = "${var.schemahero_version}"
  namespace  = "schemahero"
  depends_on = [kubernetes_namespace.cert-manager, data.external.provision_crds ]
}

variable "schemahero-chart_version" {
  type = string
  default = "1.1.0"
  }

variable "schemahero_version" {
  type = string
  default = "0.12.6"
  }
