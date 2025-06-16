#!/usr/bin/env bash

#################################################################
#
# Terraform Aliases
#
#################################################################

function printenv_tf_var {
	printenv | grep 'TF_VAR_' | while read -r line; do if [[ -z "$(echo "$line" | cut -d= -f2)" ]]; then echo "$line"; else echo "$line" | sed 's/=.*/=<sensitive>/'; fi; done
}

alias t="terraform"
alias tf-debug="export TF_LOG=DEBUG; export TF_LOG_PATH=\"/tmp/terraform.log\""
alias tf-trace="export TF_LOG=TRACE; export TF_LOG_PATH=\"/tmp/terraform.log\""
