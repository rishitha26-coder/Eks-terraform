module "eks-cluster-autoscaler" {
  source  = "lablabs/eks-cluster-autoscaler/aws"
  version = "1.6.1"
  cluster_identity_oidc_issuer = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  cluster_identity_oidc_issuer_arn = aws_iam_openid_connect_provider.openid.arn
  cluster_name = aws_eks_cluster.eks_cluster.name
  values = <<EOT
# From https://raw.githubusercontent.com/kubernetes/autoscaler/master/charts/cluster-autoscaler/values.yaml
extraArgs:
  logtostderr: true
  stderrthreshold: info
  v: 4
  # write-status-configmap: true
  # status-config-map-name: cluster-autoscaler-status
  # leader-elect: true
  # leader-elect-resource-lock: endpoints
  # skip-nodes-with-local-storage: true
  # expander: random
  scale-down-enabled: true
  balance-similar-node-groups: true
  # min-replica-count: 0
  # scale-down-utilization-threshold: 0.5
  # scale-down-non-empty-candidates-count: 30
  # max-node-provision-time: 15m0s
  # scan-interval: 10s
  # scale-down-delay-after-add: 10m
  # scale-down-delay-after-delete: 0s
  # scale-down-delay-after-failure: 3m
  # scale-down-unneeded-time: 10m
  # skip-nodes-with-system-pods: true
  # emit-per-nodegroup-metrics: true
  balancing-ignore-label_1: tool
  balancing-ignore-label_2: topology.ebs.csi.aws.com/zone
  balancing-ignore-label_3: availability_zone
  balancing-ignore-label_4: ec2-tag.docker.com/aws-autoscaling-groupName
  balancing-ignore-label_5: ec2-tag.docker.com/main-stack-name
  balancing-ignore-label_6: ec2-tag.docker.com/role
  balancing-ignore-label_7: failure-domain.beta.kubernetes.io/zone
  balancing-ignore-label_8: capacity
  balancing-ignore-label_9: eks.amazonaws.com/capacityType
EOT
	}
