resource "aws_vpc" "eks_cluster" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Cluster                           = var.eks_cluster_name
    Service                           = "soa"
    Environment = var.environment
    Name        = var.eks_cluster_name
    Service     = "soa"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_default_security_group" "default" {
    vpc_id = aws_vpc.eks_cluster.id
}

variable "aws_tgw_region_mapping" {
  default = {
    "ca-central-1" = "tgw-08aae939cde8f969f"
    "us-west-2" = "tgw-03e9ae6efda054f52"
#    "ca-central-1" = "arn:aws:ec2:ca-central-1:428180735908:transit-gateway/tgw-08aae939cde8f969f"
#    "us-west-2" = "arn:aws:ec2:us-west-2:321435445134:transit-gateway/tgw-03e9ae6efda054f52"
    }
  }

resource "aws_ec2_transit_gateway_vpc_attachment" "eks_cluster" {
        subnet_ids = [ for subnet in aws_subnet.private : subnet.id ]
        vpc_id = aws_vpc.eks_cluster.id
        transit_gateway_id = var.aws_tgw_region_mapping[var.region]
	}
