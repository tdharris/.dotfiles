#!/usr/bin/env bash

#################################################################
#
# Context Aliases
#
#################################################################

function me_k8s_context {
	local k8s_context
	if [ ! -z ${KUBECONFIG} ]; then
		k8s_context=$(awk '/current-context/{print $2}' $KUBECONFIG)
	elif [ -f "$HOME/.kube/config" ]; then
		k8s_context=$(awk '/current-context/{print $2}' $HOME/.kube/config)
	fi
	echo "${k8s_context//*cluster\//}"
}

function me {
	echo -e "\nAWS:"
	awsme | jq
	echo -e "\nK8S:"
	me_k8s_context
}
