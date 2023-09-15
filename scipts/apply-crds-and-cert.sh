certyaml () {
cat <<EOF
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
  namespace: vault-server
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-certificate
  namespace: vault-server
spec:
  commonName: vault.vault-server.svc
  dnsNames:
  - vault
  - vault.vault-server
  - vault.vault-server.svc
  - vault.vault-server.svc.cluster.local
  - vault-0.vault-internal
  - vault-2.vault-internal
  - vault-3.vault-internal
  duration: 8760h0m0s
  ipAddresses:
  - 127.0.0.1
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: selfsigned-issuer
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 4096
  renewBefore: 360h0m0s
  secretName: vault-server-tls
  subject:
    organizations:
    - vault-server
  usages:
  - server auth
  - client auth
EOF
}

apply-crds-and-cert () {
  success=false
  echo running ${0} arguments "$@"
  aws eks --profile=$1 update-kubeconfig --name "$2" --alias ${2} || return 1 
  echo applying cert-manager crds
  kubectl --context=${2} apply -f "https://github.com/jetstack/cert-manager/releases/download/v${3:-1.5.4}/cert-manager.crds.yaml" || return 1 
  echo aws-load-balancer crds
  kubectl --context=${2} apply -f "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml" || return 1
  echo kube-metrics crds
  kubectl --context=${2} apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml" || return 1
  echo applying cert
  certyaml | kubectl apply --context=${2} -f - 
  echo "success=true"
  success=true
 }
