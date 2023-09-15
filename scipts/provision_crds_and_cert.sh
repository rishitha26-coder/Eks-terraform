#!/bin/bash

stdout=

main () {
  stdout="$(aws eks --profile=$1 update-kubeconfig --name "$2" --alias ${2} 2>&1 || return 1 ; 
            kubectl --context=${2} apply -f "${3:-https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml}" 2>&1 || return 1 ;
            kubectl --context=${2} apply -f "${4}" 2>&1 || return 1 ;
   )"
 }

[[ -n "$1" ]] && [[ -n "$2" ]] && [[ -n "$4" ]] && main "$@" && echo "{success = true, stdout = \"$stdout\"}" && exit 0

echo "{ success = false, stdout = \"$stdout\" }"

exit 1
