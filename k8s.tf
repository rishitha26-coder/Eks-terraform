resource "kubernetes_cluster_role" "boot-vault" {
  metadata {
    name = "boot-vault"
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec", "pods", "pods/log", "secrets", "tmp/secrets"]
    verbs      = ["get", "list", "create"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests", "certificatesigningrequests/approval"]
    verbs      = ["get", "list", "create", "update", "approve", "delete"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["signers"]
    resource_names = ["kubernetes.io/kubelet-serving"]
    verbs      = ["approve", "sign"]
  }
}

resource "kubernetes_cluster_role_binding" "boot-vault" {
  metadata {
    name = "boot-vault"
    labels = {
        "app.kubernetes.io/name": "boot-vault"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "boot-vault"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "boot-vault"
    namespace = "vault-server"
  }
}

resource "kubernetes_service_account" "boot-vault" {
  metadata {
    name = "boot-vault"
    namespace = "vault-server"
    labels = {
      "app.kubernetes.io/name" = "boot-vault"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.vault.arn
    }
  }
  depends_on = [
     helm_release.aws-load-balancer-controller, helm_release.cert-manager, data.kubernetes_secret.vault-server-tls, kubernetes_namespace.vault-server
  ]
}

resource "kubernetes_cluster_role" "csr-approver" {
  metadata {
    name = "csr-approver"
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests/approval"]
    verbs      = ["update"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["signers"]
    resource_names = ["kubernetes.io/vault-server"]
    verbs      = ["approve", "sign"]
  }
}

resource "kubernetes_cluster_role_binding" "csr-approver" {
  metadata {
    name = "csr-approver"
    labels = {
        "app.kubernetes.io/name": "csr-approver"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "csr-approver"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "csr-approver"
    namespace = "vault-server"
  }
}

resource "kubernetes_service_account" "csr-approver" {
  metadata {
    name = "csr-approver"
    namespace = "vault-server"
    labels = {
      "app.kubernetes.io/name" = "csr-approver"
    }
  }
  depends_on = [
     helm_release.aws-load-balancer-controller, helm_release.cert-manager, data.kubernetes_secret.vault-server-tls, kubernetes_namespace.vault-server
  ]
}

resource "kubernetes_cluster_role" "csr-signer" {
  metadata {
    name = "csr-signer"
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["signers"]
    resource_names = ["kubernetes.io/vault-server"]
    verbs      = ["sign"]
  }
}

resource "kubernetes_cluster_role_binding" "csr-signer" {
  metadata {
    name = "csr-signer"
    labels = {
        "app.kubernetes.io/name": "csr-signer"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "csr-signer"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "csr-signer"
    namespace = "vault-server"
  }
}

resource "kubernetes_service_account" "csr-signer" {
  metadata {
    name = "csr-signer"
    namespace = "vault-server"
    labels = {
      "app.kubernetes.io/name" = "csr-signer"
    }
  }
}

#resource "kubernetes_job" "vault-certificate" {
#  metadata {
#    name      = "certificate-vault"
#    namespace = "vault-server"
#  }
#  spec {
#    template {
#      metadata {}
#      spec {
#        container {
#          name    = "certificate-vault"
#          image   = "amazonlinux"
#          command = ["/bin/bash","-c"]
#          args    = ["sleep 15; yum install -y awscli 2>&1 > /dev/null; export AWS_REGION=${var.region}; export NAMESPACE='vault-server'; aws sts get-caller-identity; aws s3 cp $(S3_SCRIPT_URL) ./script.sh; chmod +x ./script.sh; ./script.sh"]
#          env {
#            name  = "S3_SCRIPT_URL"
#            value = "s3://${aws_s3_bucket.vault-scripts.id}/scripts/certificates.sh"
#          }
#        }
#        service_account_name = "boot-vault"
#        restart_policy       = "Never"
#      }
#    }
#    backoff_limit = 0
#  }
#
#  depends_on = [
#    aws_eks_node_group.private,
#    kubernetes_namespace.vault-server,
#    aws_s3_bucket_object.vault-script-certificates
#  ]
#}

data "kubernetes_service" "vault-ui" {
  metadata {
    name      = "vault-ui"
    namespace = "vault-server"
  }
  depends_on = [
    helm_release.vault
  ]
}

data "kubernetes_ingress" "vault" {
  metadata {
    name      = "vault"
    namespace = "vault-server"
  }
  depends_on = [
    helm_release.vault
  ]
}

#resource "null_resource" "initial_k8s_manifests" {
#  provisioner "local-exec" {
#    command = "aws eks --profile=${var.aws_profile} update-kubeconfig --name ${var.eks_cluster_name} --alias ${var.eks_cluster_name} ; kubectl --context=${var.eks_cluster_name} apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml ;  kubectl --context=${var.eks_cluster_name} apply -f ${path.module}/vault-cert.yaml"
#    interpreter = [ "bash", "-xe" ]
#    environment = {
#      AWS_PROFILE = var.AWS_PROFILE
#      AWS_REGION = var.AWS_REGION
#      }
#    }
#  triggers = {
#    stdout     = "${data.external.read.result["stdout"]}"
#    stderr     = "${data.external.read.result["stderr"]}"
#    exitstatus = "${data.external.read.result["exitstatus"]}"
#  }
#  depends_on = [ aws_eks_cluster.eks_cluster ]
#  }
