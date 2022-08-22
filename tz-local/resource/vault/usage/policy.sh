#!/usr/bin/env bash

### https://www.vaultproject.io/api

cd /vagrant/tz-local/resource/vault/usage

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

vault secrets enable -version=2 kv
vault policy list
vault policy read default

# add policy
echo '
path "secret/*" {
  capabilities = ["list"]
}
path "secret/data/devops/*" {
  capabilities = ["create", "update", "read"]
}
path "secret/delete/devops/*" {
  capabilities = ["delete", "update"]
}
path "secret/undelete/devops/*" {
  capabilities = ["update"]
}
path "secret/destroy/devops/*" {
  capabilities = ["update"]
}
path "secret/metadata/devops/*" {
  capabilities = ["list", "read", "delete"]
}
path "secret/data/shared/*" {
  capabilities = ["read"]
}
' > devops.hcl
vault policy write tz-vault-devops devops.hcl

# add a new user
vault write auth/userpass/users/doohee.hong \
password=1111111 \
policies=tz-vault-devops
#policies=tz-vault-devops,tz

vault login -method=userpass username=doohee.hong
vault write auth/userpass/users/doohee.hong password=971097
vault token lookup

exit 0


