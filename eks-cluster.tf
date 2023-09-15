variable "kubernetes_service_ipv4_cidr" {
  type = string
  default = "172.20.0.0/16"
  }

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks.arn

  version = "${var.eks_version}"
  
  vpc_config {
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    # This uses it's own list as the list of accessors to kubernetes should change less than access to vault
    public_access_cidrs     = concat(var.kubernetes_authorized_source_ranges, [for n in aws_eip.nat : "${n.public_ip}/32"])
    subnet_ids              = concat([for s in aws_subnet.private : s.id], [for s in aws_subnet.public : s.id])
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  kubernetes_network_config {
    service_ipv4_cidr =  var.kubernetes_service_ipv4_cidr
    }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.eks-AmazonEKSServicePolicy,
    # If we stand up the cluster before this is working, we have problems!
    aws_route_table_association.private
  ]

  tags = {
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_iam_role" "eks" {
  name = var.eks_cluster_name

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
  EOF
}

data "tls_certificate" "cert" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "openid" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks.name
}

# Enable Security Groups for Pods
resource "aws_iam_role_policy_attachment" "eks-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks.name
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.eks_cluster_name}/ControlPlaneSecurityGroup"
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = aws_vpc.eks_cluster.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.eks_cluster_name}/ControlPlaneSecurityGroup"
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_security_group" "vault" {
  name        = "${var.eks_cluster_name}/vault-security-group"
  description = "Communication to vault"
  vpc_id      = aws_vpc.eks_cluster.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(local.input_authorized_source_ranges, [for n in aws_eip.nat : "${n.public_ip}/32"])
  }

  tags = {
    Name        = "${var.eks_cluster_name}/ControlPlaneSecurityGroup"
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_security_group_rule" "cluster_inbound" {
  description              = "Allow unmanaged nodes to communicate with control plane (all ports)"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 0
  type                     = "ingress"
}
