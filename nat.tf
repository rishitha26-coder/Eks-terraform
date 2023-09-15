resource "aws_eip" "nat" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  }
  
  vpc = true

  tags = {
    Name        = "eip-${var.eks_cluster_name}-${each.value.name}"
  }
}

variable "additional_eks_routes" {
  type = list(object({
      cidr_block = optional(string)
      ipv6_cidr_block = optional(string)
      egress_only_gateway_id = optional(string)
      gateway_id = optional(string)
      instance_id = optional(string)
      nat_gateway_id = optional(string)
      local_gateway_id = optional(string)
      network_interface_id = optional(string)
      transit_gateway_id = optional(string)
      vpc_endpoint_id = optional(string)
      vpc_peering_connection_id = optional(string)
	}))
  default = []
  }

variable "additional_eks_tgw_routes" {
  type = list(string)
  default = []
  }

resource "aws_nat_gateway" "nat-gw" {
  #count = var.create_public_routes ? 1 : 0
  # Only create if you're making public routes
  for_each = var.create_public_routes ? {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  } : {}

  allocation_id = aws_eip.nat[each.value.name].id
  subnet_id     = aws_subnet.public[each.value.name].id

  tags = {
    Name        = "nat-${var.eks_cluster_name}-${each.value.name}-${aws_subnet.public[each.value.name].availability_zone}"
  }
  depends_on = [ aws_subnet.public ]
}

#data "aws_subnet" "private" {
#  for_each = {
#    for subnet in local.private_nested_config : "${subnet.name}" => subnet
#  }
#  subnet_id     = aws_subnet.private[each.value.name].id
#  }

resource "aws_route_table" "private" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  }

  vpc_id = aws_vpc.eks_cluster.id

  route {
      cidr_block     = "0.0.0.0/0"
      # if I'm creating the public routes, use the gateway. if not, then use the tgw
      nat_gateway_id = var.create_public_routes ? aws_nat_gateway.nat-gw[each.value.name].id : ""
      transit_gateway_id = var.create_public_routes ? "" : var.aws_tgw_region_mapping[var.region]   
   }
  

  dynamic "route" {
    for_each = var.additional_eks_tgw_routes
    content {
      cidr_block = route.value
      transit_gateway_id = var.aws_tgw_region_mapping[var.region]
    } 
  }

  dynamic "route" {
    for_each = var.additional_eks_routes
    content {
      cidr_block = lookup(route.value, "cidr_block", null)
      ipv6_cidr_block = lookup(route.value, "ipv6_cidr_block", null)
      egress_only_gateway_id = lookup(route.value, "egress_only_gateway_id", null)
      gateway_id = lookup(route.value, "gateway_id", null)
      instance_id = lookup(route.value, "instance_id", null)
      nat_gateway_id = lookup(route.value, "nat_gateway_id", null)
      local_gateway_id = lookup(route.value, "local_gateway_id", null)
      network_interface_id = lookup(route.value, "network_interface_id", null)
      transit_gateway_id = lookup(route.value, "transit_gateway_id", null)
      vpc_endpoint_id = lookup(route.value, "vpc_endpoint_id", null)
      #vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id_by_data", "false") == "true" ? data.aws_vpc_peering_connection.main[route.key].id : lookup(route.value, "vpc_peering_connection_id", null)
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
    } 
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "rt-${var.eks_cluster_name}-${each.value.name}-${aws_subnet.public[each.value.name].availability_zone}"
  }
  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.eks_cluster
  ]
}

resource "aws_route_table_association" "private" {

  for_each = {
    for subnet in local.private_nested_config : "${subnet.name}" => subnet
  }

  subnet_id      = aws_subnet.private[each.value.name].id
  #route_table_id = "${aws_route_table.private[each.value.associated_public_subnet].id}"
  route_table_id = "${var.private_route_table_override != "" ? var.private_route_table_override : aws_route_table.private[each.value.associated_public_subnet].id}"
}


resource "aws_route_table_association" "lambda" {

  for_each = {
    for subnet in local.lambda_nested_config : "${subnet.name}" => subnet
  }

  subnet_id      = aws_subnet.lambda[each.value.name].id
  #route_table_id = "${aws_route_table.private[each.value.associated_public_subnet].id}"
  route_table_id = "${var.private_route_table_override != "" ? var.private_route_table_override : aws_route_table.private[each.value.associated_public_subnet].id}"
}
