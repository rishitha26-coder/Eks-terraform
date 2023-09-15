
path "secrets/k8s/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo" ]
}
path "secrets/devops/*"
{
  capabilities = ["read", "list"]
}
path "secrets/devops/sensitive"
{
  capabilities = [ ]
}
