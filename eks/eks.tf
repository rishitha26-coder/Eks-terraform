output "endpoint" {
  value = var.eks-endpoint
  }

variable "eks-endpoint" {
  type = string
  }

resource "null_resource" "eks" {
  triggers = { 
    endpoint = var.eks-endpoint
   }
  }   
