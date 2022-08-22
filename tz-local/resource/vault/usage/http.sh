#!/usr/bin/env bash

### https://www.vaultproject.io/api

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
vault_token=$(prop 'project' 'vault')

#set -x
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
vault -h

export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login ${vault_token}

vault kv list tz/vault
vault kv get tz/vault/course

vault kv list kv/tz-vault

echo '{
  "max_versions": 5,
  "cas_required": false,
  "delete_version_after": "3h25m19s"
}' > payload.json

curl \
    --header "X-Vault-Token: ${vault_token}" \
    --request POST \
    --data @payload.json \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/config

curl \
    --header "X-Vault-Token: ${vault_token}" \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/config

echo '{
  "options": {
    "cas": 0
  },
  "data": {
    "foo": "bar",
    "zip": "zap"
  }
}' > payload.json
curl \
    --header "X-Vault-Token: ${vault_token}" \
    --request POST \
    --data @payload.json \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/my-secret

echo '{
  "options": {
    "cas": 1
  },
  "data": {
    "foo": "bar11",
    "zip": "zap11"
  }
}' > payload.json
curl \
    --header "X-Vault-Token: ${vault_token}" \
    --request POST \
    --data @payload.json \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/my-secret

curl \
    --header "X-Vault-Token: ${vault_token}" \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/my-secret?version=1

curl \
    --header "X-Vault-Token: ${vault_token}" \
    --request DELETE \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/my-secret

echo '{
  "versions": [2]
}' > payload.json
curl \
    --header "X-Vault-Token: ${vault_token}" \
    --request POST \
    --data @payload.json \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/delete/my-secret

echo '{
  "versions": [2]
}' > payload.json
curl \
    --header "X-Vault-Token: ${vault_token}" \
    --request POST \
    --data @payload.json \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/undelete/my-secret

curl \
    --header "X-Vault-Token: ${vault_token}" \
    --request LIST \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/metadata/my-secret

curl \
    --header "X-Vault-Token: ${vault_token}" \
    http://vault.default.${eks_project}.${eks_domain}/v1/secret/metadata/my-secret

exit 0


