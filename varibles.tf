variable "region" {
  type = string
}

variable "az" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "vpc_cidr_block" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "acm_vault_arn" {
  type = string
}

variable "eks_version" {
  type = string
}

variable "public_subnet_name_1" {
  type = string
}

variable "public_subnet_name_2" {
  type = string
}

variable "public_subnet_name_3" {
  type = string
}

variable "environment_type" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_network_config" {
  type = map(object({
      cidr_block               = string
      associated_public_subnet = optional(string)
      associated_route_id = optional(string)
  }))

  default = {
    "private-eks-cluster-1" = {
        cidr_block = "10.0.0.0/22"
        associated_public_subnet = "public-eks-cluster-1"
    },
    "private-eks-cluster-2" = {
        cidr_block = "10.0.4.0/22"
        associated_public_subnet = "public-eks-cluster-2"
    },
    "private-eks-cluster-3" = {
        cidr_block = "10.0.8.0/22"
        associated_public_subnet = "public-eks-cluster-3"
    }
  }
}

variable "lambda_network_config" {
  type = map(object({
      cidr_block               = string
      associated_public_subnet = string
  }))

  default = {
  }
}

locals {
    private_nested_config = flatten([
        for name, config in var.private_network_config : [
            {
                name                     = name
                cidr_block               = config.cidr_block
                associated_public_subnet = config.associated_public_subnet
            }
        ]
    ])

    lambda_nested_config = flatten([
        for name, config in var.lambda_network_config : [
            {
                name                     = name
                cidr_block               = config.cidr_block
                associated_public_subnet = config.associated_public_subnet
            }
        ]
    ])
}

variable "s3_bucket_name" {
  type = string
}

variable "public_network_config" {
  type = map(object({
      cidr_block              = string
  }))

  default = {
    "public-eks-cluster-1" = {
        cidr_block = "10.0.12.0/22"
    },
    "public-eks-cluster-2" = {
        cidr_block = "10.0.16.0/22"
    },
    "public-eks-cluster-3" = {
        cidr_block = "10.0.20.0/22"
    }
  }
}

locals {
    public_nested_config = flatten([
        for name, config in var.public_network_config : [
            {
                name                    = name
                cidr_block              = config.cidr_block
            }
        ]
    ])
}

variable "public_dns_name" {
  type    = string
}


locals {
  input_authorized_source_ranges = concat (var.authorized_source_ranges, var.additional_authorized_source_ranges)
  }

locals {
  input_kubernetes_authorized_source_ranges = var.kubernetes_authorized_source_ranges
  }

variable "authorized_source_ranges" {
  type        = list(string)
  description = "Addresses or CIDR blocks which are allowed to connect to the Vault IP address. The default behavior is to allow anyone (10.0.0.0/0) access. You should restrict access to external IPs that need to access the Vault cluster."
  # This defaults to the vpn addresses for test and moka
  default     = [
    # test VPN
    "209.82.73.82/32", "209.82.74.66/32", "54.187.227.249/32", "44.238.169.62/32", "3.97.193.96/32", "35.182.107.146/32",
    # Artifactory
    "34.212.154.95/32",
    # ETL Servers, CRM, and legacy test services
    "54.187.253.88/32", "54.187.170.171/32", "54.186.92.116/32",
    # Buildkite Agent
    "35.166.12.86/32",
    # Vault servers (which are also build agents)
    "34.213.91.165/32",
    "52.27.12.135/32",
    "54.71.87.127/32",
    "44.241.128.40/32",
    "44.237.110.71/32",
    "52.42.94.123/32"
 ]
}

variable "additional_authorized_source_ranges" {
  type        = list(string)
  description = "Additional Addresses or CIDR blocks which are allowed to connect to the Vault IP address. The default behavior is to allow anyone (10.0.0.0/0) access. You should restrict access to external IPs that need to access the Vault cluster."
  # This defaults to the shared cluster addresses, the moka dev addresses, and the stating cluster addresses
  default     = [ "35.165.38.13/32", "34.214.164.128/32", "34.210.160.10/32" , "3.99.102.164/32", "3.96.70.160/32", "15.223.90.133/32", "54.148.17.189/32", "34.210.164.148/32", "34.214.10.78/32" , "34.216.60.61/32", "52.88.164.3/32", "52.27.89.165/32", "3.98.162.0/32", "3.98.66.95/32", "35.182.119.106/32" ]
}

variable "kubernetes_authorized_source_ranges" {
  type = list(string)
  default = [
    "34.216.60.61/32", #  Staging Zone A (opbot)
    "52.88.164.3/32", #  Staging Zone B (opbot)
    "52.27.89.165/32", #  Staging Zone C (opbot)
    "209.82.74.66/32", #  Winnipeg/East
    "209.82.73.82/32", #  Vancouver/West
    "54.187.227.249/32", #  AWS VPN (RRAS)
    "44.238.169.62/32", #  AWS VPN us-west-2 (AWS Openvpn Client)
    "3.97.193.96/32", #  AWS VPN ca-central-1 (AWS Openvpn Client)
    "52.10.231.245/32", #  Appgate VPN
    "54.201.189.125/32", #  Appgate VPN
    "35.166.12.86/32", #  buildkite
    "34.213.91.165/32", #  vault nonprod
    "54.71.87.127/32", #  vault nonprod
    "52.27.12.135/32", # vault nonprod
    "44.237.110.71/32", #  vault prod
    "44.241.128.40/32", #  vault prod
    "52.42.94.123/32", #  vault prod
    "34.212.154.95/32" #  Jfrog
   ]
  }

variable "aws_profile" {
  type = string
}

variable "cert-manager_version" {
  type = string
  default = "1.5.4"
  }

variable "vault_chart_version" {
  type = string
  default = "0.19.0"
  }

variable "vault_version" {
  type = string
  default = "1.9.4"
  }

variable "aws_account_id" {
  type = string
  }

variable "git_remote_origin_branch" {
  type = string
  }

variable "git_remote_origin_url" {
  type = string
  }

variable "costcentre" {
  type = string
  default = "test DevOps"
  }

variable "aws-eks-image-account" {
  type = string
  default = "602401143452"
}

variable "vault_dns_prefix" {
  type = string
  default = ""
  }

variable "private_route_table_override" {
  type = string
  default = ""
}

variable "public_route_table_override" {
  type = string
  default = ""
}

locals {
   vault_dns_name = "${var.vault_dns_prefix != "" ? var.vault_dns_prefix : var.eks_cluster_name}.${var.public_dns_name}"
   }

variable "instance_types" {
  default = ["t3.small"]
  type = list
  }

variable "eks_ssh_key" {
  # This is the nonproduction key. This key should be specified in production!
  type = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBB1K0TNjPMQL+AVAUk3ZTanfvv+g+TMiHV0+mQ4MYweVUVYv1joZBLaKhimZQH1hdIQzg3cAdI3xHSZGy95l6myhMlz+0VPUi31rDzxAMbAGr9bUwqE/bzMNn1AC1auh5bzR9yTMAXiawGSZOmqKG+cww73oSQ/WALrNVsN7RYfPk/2r//oGMCTK59JglotHDS/LwOZq/G8/MLpJVQ0wszya3ggLwdRcMVioXCEhcMmLkVfmi4nZIlnofBvUKPw4OEtIHwWTmGRtplmu5Qj8PscmylntuS/GVHTxyTQY6IlInPF5LDw58Df3wpr8KAdzkmbggoNizWZ6dPaRBcad0iyV974pFLQmhVt/bGye9wEsWzCBwqyO5uuNKd8UOxAezo/7JZQ4rZ4QtCMrznUkCVynfINMFP/O5xDhlNZCDf7UDYQMQjRONyNqo7Kcd68lp3wzyj371rit2J9G4p8bGT+9QCTYqwC91hBtRZ2KRz8r4ffvlZj8+wKPdOHZK1UGX3HdS6GO/ugRHHhzIuQIhU1FnkPLxSTkChGjBPi+AV5/SMhJQbsCUh5+G5lKY6pYg5KKLkQDJZtOw9rTeo038KPXIZzwASdcybfOAYmbL/syMz1C7TpVddA4P0KSpE8+85rZiquIYvv1pI/GAIluK0OeQjjs+T1Bd8U+7pVgNDw== ist-devops@test.ca"
  }

variable "create_public_routes" {
  type = bool
  default = true
  }

variable "vault_alb_scheme" {
  type = string
  default = "internet-facing"
  }
