resource "kubernetes_namespace" "vault-server" {
  metadata {
    name = "vault-server"
  }
}

data "kubernetes_service_account" "vault" {
  metadata {
    name = "vault"
    namespace = "vault-server"
    }
  depends_on = [ helm_release.vault ]
  }

data "kubernetes_secret" "vault-eks-token" {
  metadata {
    name = "${data.kubernetes_service_account.vault.default_secret_name}"
    namespace = "vault-server"
  }
}

data "template_file" "vault-values" {
#             service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443,8200" 
#             service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
#             service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8200"
#             service.beta.kubernetes.io/aws-load-balancer-traffic-port: "8200" 
#             kubernetes.io/ingress.class: alb
#            service.beta.kubernetes.io/sandbox.testdevops.com
#            service.beta.kubernetes.io/aws-load-balancer-type: nlb-ip
#            external-dns.alpha.kubernetes.io/ttl: "30"
#            service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
  template = <<EOF
        global:
          enabled: true
          tlsDisable: false
        debug: true
        auditStorage:
          enabled: true
        standalone:
          enabled: false
        ui:
          enabled: true
          externalPort: 443
          serviceType: ClusterIP
#          annotations: |
#             service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing 
#             service.beta.kubernetes.io/aws-load-balancer-type: external
#             service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
#             service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ${var.acm_vault_arn} 
#             service.beta.kubernetes.io/aws-load-balancer-backend-protocol: HTTPS
#             service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/ui/" 
#             service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: HTTPS
#             service.beta.kubernetes.io/aws-load-balancer-traffic-port: "8200" 
#             service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443" 
#             service.beta.kubernetes.io/aws-load-balancer-listen-ports: "443" 
#             service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS-1-2-2017-01"
#             service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: "preserve_client_ip.enabled=true"
#        csi:
#          enabled: true
        server:
          nodeSelector: |
            tool: vault
#            eks.amazonaws.com/nodegroup: vault-prod-managed-nodegroup-private-medium
#            eks.amazonaws.com/nodegroup: private-node-group-${var.eks_cluster_name}
          extraVolumes:
          - type: secret
            name: vault-server-tls
          image:
            repository: "vault"
            tag: "${var.vault_version}"
          logLevel: "debug"
          service:
            type: ClusterIP
            targetPort: 8200
          ingress:
            enabled: true
            pathType: Prefix
            extraPaths:
              - path: /*
                pathType: ImplementationSpecific
                backend:
                  service:
                    name: vault-active
                    port:
                      number: 8200
            hosts:
              - host: "${local.vault_dns_name}"
            annotations: |
              kubernetes.io/ingress.class: alb
              alb.ingress.kubernetes.io/load-balancer-name: ${var.eks_cluster_name}
              alb.ingress.kubernetes.io/scheme: ${var.vault_alb_scheme}
              alb.ingress.kubernetes.io/certificate-arn: ${var.acm_vault_arn} 
              alb.ingress.kubernetes.io/backend-protocol: HTTPS
              alb.ingress.kubernetes.io/healthcheck-path: /ui/
              alb.ingress.kubernetes.io/healthcheck-protocol: HTTPS
              alb.ingress.kubernetes.io/target-type: ip
              alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
              alb.ingress.kubernetes.io/healthcheck-interval: '30'
              alb.ingress.kubernetes.io/inbound-cidrs: "${join(", ",concat(local.input_authorized_source_ranges, [for n in aws_eip.nat : "${n.public_ip}/32"]))}"
              external-dns.alpha.kubernetes.io/hostname: "${local.vault_dns_name}"
          serviceAccount:
            annotations: |
              eks.amazonaws.com/role-arn: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.eks_cluster_name}_vault-unseal"
          extraEnvironmentVars: 
            AWS_ROLE_SESSION_NAME: some_name
          ha:
            enabled: true
            nodes: 3
            raft:
              enabled: true
              setNodeId: true
              config: |
                ui = true

                listener "tcp" {
                  tls_disable = 0
                  tls_cert_file = "/vault/userconfig/vault-server-tls/tls.crt"
                  tls_key_file  = "/vault/userconfig/vault-server-tls/tls.key"
                  tls_client_ca_file = "/vault/userconfig/vault-server-tls/ca.crt"
                  address = "[::]:8200"
                  cluster_address = "[::]:8201"
                }

                storage "raft" {
                  path = "/vault/data"
                  retry_join {
                    leader_api_addr = "https://vault-0.vault-internal:8200"
                    leader_ca_cert_file = "/vault/userconfig/vault-server-tls/ca.crt"
                    leader_client_cert_file = "/vault/userconfig/vault-server-tls/tls.crt"
                    leader_client_key_file = "/vault/userconfig/vault-server-tls/tls.key"
                  }
                  retry_join {
                    leader_api_addr = "https://vault-1.vault-internal:8200"
                    leader_ca_cert_file = "/vault/userconfig/vault-server-tls/ca.crt"
                    leader_client_cert_file = "/vault/userconfig/vault-server-tls/tls.crt"
                    leader_client_key_file = "/vault/userconfig/vault-server-tls/tls.key"
                  }
                  retry_join {
                    leader_api_addr = "https://vault-2.vault-internal:8200"
                    leader_ca_cert_file = "/vault/userconfig/vault-server-tls/ca.crt"
                    leader_client_cert_file = "/vault/userconfig/vault-server-tls/tls.crt"
                    leader_client_key_file = "/vault/userconfig/vault-server-tls/tls.key"
                  }
                  autopilot {
                    cleanup_dead_servers = "true"
                    last_contact_threshold = "200ms"
                    last_contact_failure_threshold = "10m"
                    max_trailing_logs = 250000
                    min_quorum = 5
                    server_stabilization_time = "10s"
                  }
                }

                service_registration "kubernetes" {}

                seal "awskms" {
                  region     = "${var.region}"
                  kms_key_id = "${aws_kms_key.vault-kms.key_id}"
                }
   EOF
}

resource "helm_release" "vault" {
  name       = "vault"

  chart      = "vault"
  values     = [data.template_file.vault-values.rendered]
  repository = "https://helm.releases.hashicorp.com"
  namespace  = "vault-server"
  version = var.vault_chart_version

  set {
    name = "ui.loadbalancersourceranges"
    value = "{${join(",",concat(local.input_authorized_source_ranges, [for n in aws_eip.nat : "${n.public_ip}/32"]))}}"
    }
  depends_on = [ 
     helm_release.aws-load-balancer-controller, helm_release.cert-manager, data.kubernetes_secret.vault-server-tls, aws_secretsmanager_secret.vault-secret, data.external.provision_crds
     # Disabled for now
     #, helm_release.secrets-store-csi-driver
  ]
}

data "kubernetes_secret" "vault-server-tls" {
  metadata {
    name = "vault-server-tls"
    namespace = "vault-server"
    }
  binary_data = {
    "ca.crt" = ""
    "tls.crt" = ""
    "tls.key" = ""
    }
  depends_on = [
      helm_release.aws-load-balancer-controller, helm_release.cert-manager
    ]
#  lifecycle {
#    ignore_changes = [ data, binary_data, annotations]
#  }
  }

resource "aws_iam_role" "vault-unseal" {
  name = "${var.eks_cluster_name}_vault-unseal"

  assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": aws_iam_openid_connect_provider.openid.arn
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "${replace(aws_iam_openid_connect_provider.openid.url, "https://", "")}:sub": "system:serviceaccount:vault-server:vault"
                    }
                }
            }
        ]
    })

  tags = {
    Environment = "core"
  }
}

resource "aws_iam_role_policy" "vault-unseal" {
  name = "${var.eks_cluster_name}_vault-unseal"
  role = aws_iam_role.vault-unseal.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:GetRole",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:role/${var.eks_cluster_name}_vault-unseal"
      },
      {
        Action = [
          "kms:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "vault" {
  name = "${var.eks_cluster_name}_vault"

  assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": aws_iam_openid_connect_provider.openid.arn
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "${replace(aws_iam_openid_connect_provider.openid.url, "https://", "")}:sub": "system:serviceaccount:vault-server:boot-vault"
                    }
                }
            }
        ]
    })

  tags = {
    Environment = "core"
  }
}

resource "aws_iam_role_policy" "vault" {
  name   = "${var.eks_cluster_name}_vault"
  role   = aws_iam_role.vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:vault-audit-logs"
      },
      {
        Action   = [
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:vault-audit-logs:log-stream:*"
      },
      {
        Action   = [
          "ec2:DescribeInstances",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:UpdateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.vault-secret.arn
      },
      {
        Action   = [
          "iam:GetRole"
        ]
        Effect   = "Allow"
        Resource = aws_iam_role.vault.arn
      }
    ]
  })
}

resource "aws_kms_key" "vault-kms" {
  description             = "Vault Seal/Unseal key"
  deletion_window_in_days = 7

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Action": [
        "kms:*"
      ],
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "Allow administration of the key",
      "Action": [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      "Principal": {
        "AWS": [
            "${aws_iam_role.vault-unseal.arn}",
            "${aws_iam_role.vault.arn}"
        ]
       }
    },
    {
      "Sid": "Allow use of the key",
      "Action": [
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext"
      ],
      "Principal": {
        "AWS": [
            "${aws_iam_role.vault.arn}",
            "${aws_iam_role.vault-unseal.arn}"
        ]
      },
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOT
  depends_on = [ aws_iam_role.vault, aws_iam_role.vault-unseal ]
}

resource "random_string" "vault-secret-suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "aws_secretsmanager_secret" "vault-secret" {
  name        = "${var.eks_cluster_name}-secret-${random_string.vault-secret-suffix.result}"
  kms_key_id  = aws_kms_key.vault-kms.key_id
  description = "Vault Root/Recovery key"
#  lifecycle {
#    ignore_changes = [ all ]
#  }
}

resource "aws_route53_record" "vault" {
  zone_id    = data.aws_route53_zone.public.zone_id
  name       = "${local.vault_dns_name}"
  type       = "CNAME"
  ttl        = "300"
  #records    = [data.kubernetes_service.vault-ui.status.0.load_balancer.0.ingress.0.hostname]
  records    = [data.kubernetes_ingress.vault.status.0.load_balancer.0.ingress.0.hostname]
  
  depends_on = [
    helm_release.vault,
    data.kubernetes_service.vault-ui
  ]
}

resource "aws_s3_bucket" "vault-scripts" {
  bucket = "bucket-${data.aws_caller_identity.current.account_id}-${var.region}-${var.eks_cluster_name}-scripts"
  acl    = "private"

  tags = {
    Name        = "Vault Scripts"
    Environment = "core"
  }
}

resource "aws_s3_bucket_object" "vault-script-bootstrap" {
  bucket = aws_s3_bucket.vault-scripts.id
  key    = "scripts/bootstrap.sh"
  #source = "scripts/bootstrap.sh"
  etag = filemd5("${path.module}/scripts/bootstrap.sh")
  content = file("${path.module}/scripts/bootstrap.sh")
}

resource "aws_s3_bucket_object" "vault-script-certificates" {
  bucket = aws_s3_bucket.vault-scripts.id
  key    = "scripts/certificates.sh"
  content = file("${path.module}/scripts/certificates.sh")
  etag = filemd5("${path.module}/scripts/certificates.sh")
}
