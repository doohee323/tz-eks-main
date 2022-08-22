#!/usr/bin/env bash

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

# set a secret engine
vault secrets list
vault secrets list -detailed
vault secrets enable -path=test1 kv
vault secrets enable -path=test1 -version=2 kv
vault secrets disable test1

# add a userpass
vault auth enable userpass
vault write auth/userpass/users/doohee.hong password=1111111 policies=tz-vault-devops
vault delete auth/userpass/users/doohee.hong
vault list auth/userpass/users
vault read auth/userpass/users/doohee.hong

#vault secrets enable -path=secret/devops/ kv
#vault secrets list -detailed | grep devops
vault kv enable-versioning secret

vault login -method=userpass username=doohee.hong

# add a certs
vault kv put secret/devops/database type=mysql name=testdb host=localhost port=2222 passwod=1111

vault kv put secret/devops/demo cert=@authorized_keys
vault kv put secret/devops/devops_secret devops=3333
vault kv get secret/devops/devops_secret
vault kv put secret/devops/devops_secret devops=4444
vault kv get -version=1 secret/devops/devops_secret
vault kv delete secret/devops/devops_secret
vault kv undelete -versions=2 secret/devops/devops_secret
vault kv get secret/devops/devops_secret

exit 0

vault auth list
vault list auth/kubernetes/role
vault list auth/userpass/users
vault read auth/userpass/users/doohee.hong

vault read auth/kubernetes/role/datateam-dev


policies

path "auth/kubernetes/role" {
    capabilities = ["read"]
}
