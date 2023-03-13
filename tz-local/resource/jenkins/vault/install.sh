#!/usr/bin/env bash

cd /vagrant/tz-local/resource/jenkins/vault

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id')
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key')
vault_token=$(prop 'project' 'vault')

#set -x
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
vault -h

export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login ${vault_token}

vault auth enable approle
vault secrets enable kv-v2
vault kv enable-versioning secret/

vault policy write jenkins jenkins-policy.hcl
vault policy list

vault write auth/approle/role/jenkins \
     secret_id_ttl=0 \
     token_num_uses=0 \
     token_ttl=0 \
     token_max_ttl=0 \
     secret_id_num_uses=0 \
     policies="jenkins"

# Get RoleID and SecretID
vault read auth/approle/role/jenkins/role-id
#Key        Value
#---        -----
#role_id    06e1f9bf-xxx

vault write -f auth/approle/role/jenkins/secret-id
#Key                   Value
#---                   -----
#secret_id             4b59eaa2-xxx

# Create dbinfo secret with 3 keys to read in jenkins pipeline
tee dbinfo.json <<"EOF"
{
  "name": "localhost",
  "passwod": "1111",
  "ttl": "30s"
}
EOF
vault kv put secret/devops-dev/dbinfo @dbinfo.json
vault kv delete secret/devops-dev/dbinfo
vault kv get secret/devops-dev/dbinfo

exit 0
