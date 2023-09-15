output "eks-endpoint" {
    value = aws_eks_cluster.eks_cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
    value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks_issuer_url" {
    value = aws_iam_openid_connect_provider.openid.url
}

output "vault_secret_name" {
    value = aws_secretsmanager_secret.vault-secret.name
}

output "vault_secret_arn" {
    value = aws_secretsmanager_secret.vault-secret.arn
}

#output "nat1_ip" {
#    value = aws_eip.nat["public-security-1"].public_ip
#}

#output "nat2_ip" {
#    value = aws_eip.nat["public-security-2"].public_ip
#}

#output "nat3_ip" {
#    value = aws_eip.nat["public-security-3"].public_ip
#}

output "nat_ips" {
  value = toset ([
    for ip in aws_eip.nat : ip.public_ip
 ])
 }

output "vault_url" {
  value = aws_route53_record.vault.name
  }

data "aws_secretsmanager_secret_version" "vault-secret" {
  secret_id = aws_secretsmanager_secret.vault-secret.arn
  depends_on = [ helm_release.vault , data.external.initialize-vault ]
  }

output "vault_secret_value" {
  value = data.aws_secretsmanager_secret_version.vault-secret.secret_string
  sensitive = true
  depends_on = [ helm_release.vault , data.external.initialize-vault ]
  }

output "eks-cluster-ca" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
  sensitive = true
  depends_on = [ helm_release.vault , data.external.initialize-vault ]
  }

output "vault-eks-token" {
  value = data.kubernetes_secret.vault-eks-token.data["token"]
  sensitive = true
  depends_on = [ helm_release.vault ]
  }

output "artifactory-kubeconfig" {
  value = data.template_file.artifactory-kubeconfig.rendered
  sensitive = true
  }
