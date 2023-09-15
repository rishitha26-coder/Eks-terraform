resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_cluster.id

  tags = {
    Environment = "core"
    Name        = "${var.eks_cluster_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_cluster.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Environment = "core"
    Name        = "${var.eks_cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  }

  subnet_id      = aws_subnet.public[each.value.name].id
  route_table_id = aws_route_table.public.id
}
