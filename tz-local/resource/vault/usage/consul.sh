#!/usr/bin/env bash

# https://learn.hashicorp.com/tutorials/vault/pki-engine

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
vault_token=$(prop 'project' 'vault')

#set -x
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
vault -h

export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login ${vault_token}

export CONSUL_HTTP_ADDR="localhost:8500"
#export CONSUL_HTTP_ADDR="dooheehong323:8500"
consul members
consul acl bootstrap

exit 0
