
data "http" "aws-load-balancer-controller-policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v${var.aws-load-balancer-controller_version}/docs/install/iam_policy.json"
  #name = "aws-load-balancer-controler-policy"
  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

resource "aws_iam_policy" "aws-load-balancer-controller" {
  name        = "${var.eks_cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for the AWS Load Balancer Controller"
  policy = data.http.aws-load-balancer-controller-policy.body
}

module "iam_assumable_role_aws_load_balancer_controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 4.0"

  create_role                   = true
  role_name                     = "${var.eks_cluster_name}-aws-load-balancer-controller"
  provider_url                  = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  role_policy_arns              = [aws_iam_policy.aws-load-balancer-controller.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
}

resource "kubernetes_service_account" "aws-load-balancer-controller" {
  metadata {
    name = "aws-load-balancer-controller"
     
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_assumable_role_aws_load_balancer_controller.iam_role_arn
    }

  }
}

resource "helm_release" "aws-load-balancer-controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  set {
        name = "clusterName"
        value = var.eks_cluster_name
    }
  set {
        name = "serviceAccount.create"
        value = false
    }
  set {
        name = "serviceAccount.name"
        value = "aws-load-balancer-controller"
    }
  set {
        name = "image.repository"
        value = "${var.aws-eks-image-account}.dkr.ecr.${var.region}.amazonaws.com/amazon/aws-load-balancer-controller"
      }
  set {
        name = "region"
        value = var.region
      }
  set {
        name = "vpcId"
        value = aws_vpc.eks_cluster.id
      }

  version = var.aws-load-balancer-controller_chart_version
  namespace  = "kube-system"
  depends_on = [kubernetes_service_account.aws-load-balancer-controller, data.external.provision_crds ]
}

variable "aws-load-balancer-controller_chart_version" {
  type = string
  default = "1.3.2"
  }

variable "aws-load-balancer-controller_version" {
  type = string
  default = "2.3.0"
}
