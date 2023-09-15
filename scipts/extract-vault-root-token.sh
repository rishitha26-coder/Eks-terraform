extract-vault-root-token () {
  success=false
  echo running extract-vault-root-token "$@"
  profile=$1
  name=$2
  secret=$3
  shift 3
  RETURN_VALUE=$(aws secretsmanager get-secret-value --region ${AWS_REGION} --profile ${profile} --secret-id ${secret} | awk '$0 ~ /Initial Root Token: / {print $4}' )
  [[ -n "$RETURN_VALUE" ]] && success=true
 }
