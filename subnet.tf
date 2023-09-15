resource "aws_subnet" "private" {
  for_each = {
    for subnet in local.private_nested_config : "${subnet.name}" => subnet
  }

  vpc_id                  = aws_vpc.eks_cluster.id
  cidr_block              = each.value.cidr_block
  availability_zone       = var.az[index(local.private_nested_config, each.value)]
  map_public_ip_on_launch = false

  tags = {
    Cluster                           = var.eks_cluster_name
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
#    Environment                       = var.environment
    Name                              = "${each.value.name}-${var.az[index(local.private_nested_config, each.value)]}"
    "kubernetes.io/role/internal-elb" = 1
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "lambda" {
  for_each = {
    for subnet in local.lambda_nested_config : "${subnet.name}" => subnet
  }

  vpc_id                  = aws_vpc.eks_cluster.id
  cidr_block              = each.value.cidr_block
  availability_zone       = var.az[index(local.lambda_nested_config, each.value)]
  map_public_ip_on_launch = false

  tags = {
    Cluster                           = var.eks_cluster_name
    Service                           = "soa"
    Function                          = "lambda"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
#    Environment                       = var.environment
    Name                              = "${each.value.name}-${var.az[index(local.lambda_nested_config, each.value)]}"
    "kubernetes.io/role/internal-elb" = 1
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "public" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  }

  vpc_id                  = aws_vpc.eks_cluster.id
  cidr_block              = each.value.cidr_block
  availability_zone       = var.az[index(local.public_nested_config, each.value)]
  map_public_ip_on_launch = true

  tags = {
    Environment              = var.eks_cluster_name
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    Name                     = each.value.name
    "kubernetes.io/role/elb" = 1
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
