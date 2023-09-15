variable "private_node_types" {
  type = list
  default = [ "t3.medium" ]
  }

variable "private_highload_node_types" {
  type = list
  # This would be multiple sizes, but there's an outstanding bug in aws_eks_node_group that prevents this from working as expected.
  # https://github.com/hashicorp/terraform-provider-aws/issues/21203
  # Once this issue is fixed, should probably be expanded
  default = [ "t3.large" ]
  }

variable "max_private_highload_nodegroup_size" {
  type = string
  default = "10"
  }

variable "max_private_nodegroup_size" {
  type = string
  default = "2"
  }

variable "min_private_highload_nodegroup_size" {
  type = string
  default = "0"
  }

variable "min_private_nodegroup_size" {
  type = string
  default = "1"
  }

variable "min_public_nodegroup_size" {
  type = string
  default = "1"
  }

variable "max_public_nodegroup_size" {
  type = string
  default = "5"
  }

variable "public_node_types" {
  type = list
  default = [ "t3.small" ]
  }

resource "aws_eks_node_group" "private" {
  for_each = {
    for subnet in local.private_nested_config : "${subnet.name}" => subnet
  }
  subnet_ids      = [aws_subnet.private[each.value.name].id]

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name_prefix = "private-${aws_subnet.private[each.value.name].availability_zone}-"
  node_role_arn   = aws_iam_role.node-group.arn

  labels          = {
    "type" = "private"
    "tool" = "vault"
    "capacity" = "low"
    "k8s-app" = "kube-dns"
    "availability_zone" = "${aws_subnet.private[each.value.name].availability_zone}"
  }

  instance_types = var.private_node_types

  scaling_config {
    desired_size = var.min_private_nodegroup_size
    max_size     = var.max_private_nodegroup_size
    min_size     = var.min_private_nodegroup_size
  }

  update_config {
    max_unavailable = 1
    }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node-group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node-group-AmazonEC2ContainerRegistryReadOnly
  ]

  tags = {
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled" = "true"
  }

  remote_access {
    ec2_ssh_key = "${aws_key_pair.eks-ssh-key.key_name}"
    source_security_group_ids = [ aws_security_group.eks_nodes.id ]
  }
}

resource "aws_eks_node_group" "private_highload" {
  for_each = {
    for subnet in local.private_nested_config : "${subnet.name}" => subnet
  }
  subnet_ids      = [aws_subnet.private[each.value.name].id]

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name_prefix = "highcap-${aws_subnet.private[each.value.name].availability_zone}-"
  node_role_arn   = aws_iam_role.node-group.arn

  labels          = {
    "type" = "private"
    "tool" = "vault"
    "capacity" = "high"
    "k8s-app" = "kube-dns"
    "availability_zone" = "${aws_subnet.private[each.value.name].availability_zone}"
  }

  instance_types = var.private_highload_node_types

  scaling_config {
    # We start off with 1 so that when nodegroups are being rebuilt with autoscaling, they automatically spin
    # up some nodes to make the rebuild of cluster with the new nodegroups safer. Autoscaling should turn them
    # off relatively quickly once other options are available, so this is fine
    desired_size     = var.min_private_highload_nodegroup_size
    max_size     = var.max_private_highload_nodegroup_size
    min_size     = var.min_private_highload_nodegroup_size
  }

  update_config {
    max_unavailable = 1
    }

  lifecycle {
    create_before_destroy = true 
    ignore_changes        = [scaling_config[0].desired_size]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node-group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node-group-AmazonEC2ContainerRegistryReadOnly
  ]

  tags = {
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled" = "true"
  }

  remote_access {
    ec2_ssh_key = "${aws_key_pair.eks-ssh-key.key_name}"
    source_security_group_ids = [ aws_security_group.eks_nodes.id ]
  }
}

resource "aws_eks_node_group" "public" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  }
#  count = var.create_public_subnets ? 1 : 0
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name_prefix = "public-${aws_subnet.public[each.value.name].availability_zone}-"
#  node_group_name_prefix = "public-"
  node_role_arn   = aws_iam_role.node-group.arn
  subnet_ids      = [for s in aws_subnet.public : s.id]

  labels          = {
    "type" = "public"
  }

  instance_types =  var.public_node_types

  scaling_config {
    desired_size = var.min_public_nodegroup_size
    max_size     = var.max_public_nodegroup_size
    min_size     = var.min_public_nodegroup_size
  }

  update_config {
    max_unavailable = 1
    }

  lifecycle {
    create_before_destroy = true 
    ignore_changes        = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node-group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node-group-AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled" = "true"
  }
  remote_access {
    ec2_ssh_key = "${aws_key_pair.eks-ssh-key.key_name}"
    source_security_group_ids = [ aws_security_group.vault.id, aws_security_group.eks_nodes.id ]
  }
}

resource "aws_key_pair" "eks-ssh-key" {
  key_name = "${var.eks_cluster_name}--eks-ssh-key"
  public_key = var.eks_ssh_key
  }

resource "aws_iam_role" "node-group" {
  name = "eks-node-group-role-${var.eks_cluster_name}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  tags = {
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
}

resource "aws_iam_role_policy_attachment" "node-group-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node-group.name
}

resource "aws_iam_role_policy_attachment" "node-group-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node-group.name
}

resource "aws_iam_role_policy_attachment" "node-group-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node-group.name
}

#resource "aws_iam_role_policy" "node-group-ClusterAutoscalerPolicy" {
#  name = "${var.eks_cluster_name}-auto-scaler"
#  role = aws_iam_role.node-group.id
#
#  policy = jsonencode({
#    "Version" = "2012-10-17"
#    "Statement" = [
#      {
#        "Action" = [
#            "autoscaling:DescribeAutoScalingGroups",
#            "autoscaling:DescribeAutoScalingInstances",
#            "autoscaling:DescribeLaunchConfigurations",
#            "autoscaling:DescribeTags",
#            "autoscaling:SetDesiredCapacity",
#            "autoscaling:TerminateInstanceInAutoScalingGroup"
#        ],
#        "Effect"   = "Allow",
#        "Resource" = "*"
#      },
#    ],
#    "Condition": {
#        "StringEquals": {
#          "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled": "true",
#          "autoscaling:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}": "owned"
#        }
#      }
#  })
#}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.eks_cluster_name}/ClusterSharedNodeSecurityGroup"
  description = "Communication between all nodes in the cluster"
  vpc_id      = aws_vpc.eks_cluster.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.eks_cluster_name}/ClusterSharedNodeSecurityGroup"
#    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
}
