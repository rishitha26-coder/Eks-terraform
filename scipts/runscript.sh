#!/bin/bash

shopt -s extglob

main () {
        script="$1"
        . $script || exit 1
	function="${script##*/}"
	function="${function%.sh}"
	TEMPFILE=$(mktemp /tmp/runscript-${function}-$(date +%F_%H-%M-%S))
	shift
	stdout=
	export success=false

	[[ -n "$1" ]] && [[ -n "$2" ]] || exit 1
	a=1000
	echo "{" | tee ${TEMPFILE}.json
	${function} "$@" > ${TEMPFILE} 2>&1
        [[ "$?" == "0" ]] && success=true
        while read line ; do
	    echo "  \"stdout${a}\" : $(echo -n "${line}"  | sed 's/"//g' | jq --slurp --raw-input)", 
	    let a++
	  done < ${TEMPFILE} | tee -a ${TEMPFILE}.json
	if [[ -n "$RETURN_VALUE" ]] ; then
		echo -e "   \"return_value\" : \"${RETURN_VALUE}\"," | tee -a ${TEMPFILE}.json
	fi
	echo -e "   \"success\" : \"${success}\" }" | tee -a ${TEMPFILE}.json

	#[[ "$success" = "true" ]] && exit 0
	[[ "$success" = "true" ]] && rm -f ${TEMPFILE} ${TEMPFILE}.json && exit 0
}

main "$@"
