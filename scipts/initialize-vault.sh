initialize-vault () {
  TEMPFILE2=$(mktemp /tmp/test.XXXXXX)
  success=false
  echo running ${0} arguments "$@"
  profile=$1
  name=$2
  secret=$3
  shift 3
  aws eks --profile=${profile} update-kubeconfig --name "${name}" --alias "${name}" || return 1
  TIMEOUT=300
  a=0
  ATTEMPTS=10
  attempt=1
  result=0
  for pod in $@ ; do
    echo "Checking of vault pod ${pod} is initialized..." >&2
    while ! kubectl get --context=${name} -n vault-server pod/${pod} > /dev/null 2>&1 && \
         [[ "$a" -lt "$TIMEOUT" ]] ; do
         let a++
         sleep 1s
    done
    kubectl get --context=${name} -n vault-server pod/${pod}
    while [[ ${attempt} -lt ${ATTEMPTS} ]] ; do
	    echo "Validating status of ${pod}"
	    if ! kubectl exec --context=${name} -n vault-server -i ${pod} -- vault operator init -status -tls-skip-verify ; then
		    echo "Initializing vault on ${pod}" >&2
		    # needs to delay so that nodes can communicate before initialization happens
                    sleep 10s
		    SECRETVALUE=
		    SECRETVALUE="$(kubectl exec --context=${name} -n vault-server -i ${pod} -- vault operator init -recovery-shares=5 -recovery-threshold=3 -tls-skip-verify | tee ${TEMPFILE2})"
		    if [[ "$SECRETVALUE" != *"Initial Root Token:"* ]] ; then
			let attempts++
			sleep 5s
                        continue
		    fi
		    echo DEBUG ${SECRETVALUE} 
	            echo "Putting secret into secretsmanager."
		    if [[ "${pod}" = "vault-0" ]] ; then
		    	aws secretsmanager put-secret-value --region ${AWS_REGION} --profile ${profile} --secret-id ${secret} --secret-string "${SECRETVALUE}"
			result=$?
		    else
			aws secretsmanager create-secret --region ${AWS_REGION} --profile ${profile} --name ${secret}-${pod} --secret-string "${SECRETVALUE}" --description "Unseal keys for ${pod}"
		    fi
	    else
    	        echo "Vault pod ${pod} initialized successfully!"
		result=0
		continue 2
	    fi
    done
  done
  rm -f "${TEMPFILE2}"
  echo "success=true"
  success=true
 }
