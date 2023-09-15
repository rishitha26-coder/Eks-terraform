variable "app_namespaces" {
  type = list
  default = [ "trade", "mogo" ]
  }

resource "kubernetes_namespace" "app" {
  for_each = toset(var.app_namespaces)
  metadata {
    name = each.key 
	}
  }

# https://medium.com/@chin.tong.work/terraform-rbac-namespace-in-multi-tenant-eks-7b408f222987
resource "kubernetes_role_binding" "artifactory" {
  for_each = toset(var.app_namespaces)
  metadata {
    name = "artifactory"
    namespace = each.key
    labels = {
        "app.kubernetes.io/name": "artifactory"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "artifactory"
    namespace = "default"
  }
 depends_on = [
    kubernetes_namespace.app,
    kubernetes_service_account.artifactory
  ]
}

resource "kubernetes_service_account" "artifactory" {
  metadata {
    name = "artifactory"
    namespace = "default"
    labels = {
      "app.kubernetes.io/name" = "artifactory"
    }
  }
  depends_on = [
     helm_release.aws-load-balancer-controller, helm_release.cert-manager, data.kubernetes_secret.vault-server-tls, kubernetes_namespace.vault-server
  ]
}

data "kubernetes_secret" "artifactory_secret" {
  metadata {
    name = kubernetes_service_account.artifactory.default_secret_name
  }
 }

output "artifactory_secret" {
  value = data.kubernetes_secret.artifactory_secret.data["token"]
  sensitive = true
  }

data "template_file" "artifactory-kubeconfig" {
  template = <<EOF
apiVersion: v1
kind: Config
clusters:
- name: ${aws_eks_cluster.eks_cluster.name}
  cluster:
    certificate-authority-data: ${aws_eks_cluster.eks_cluster.certificate_authority[0].data}
    server: ${module.eks.endpoint}
contexts:
- name: ${aws_eks_cluster.eks_cluster.name}
  context:
    cluster: ${aws_eks_cluster.eks_cluster.name}
    namespace: default
    user: artifactory-user
current-context: ${aws_eks_cluster.eks_cluster.name}
users:
- name: artifactory-user
  user:
    token: ${data.kubernetes_secret.artifactory_secret.data["token"]}
EOF
  }
