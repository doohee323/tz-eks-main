#!/usr/bin/env bash

#https://m.blog.naver.com/alice_k106/221803861645
#https://www.vaultproject.io/docs/secrets/ssh/signed-ssh-certificates

#bash /vagrant/tz-local/resource/vault/ca/install.sh
cd /vagrant/tz-local/resource/vault/ca

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id')
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key')
vault_kms_key=$(aws kms list-aliases | grep ${eks_project}-vault-kms-unseal -A 1 | tail -n 1 | awk -F\" '{print $4}')
vault_token=$(prop 'project' 'vault')
#export VAULT_TOKEN=${vault_token}
NS=vault

export VAULT_ADDR="http://vault.default.${eks_project}.${eks_domain}"
echo "VAULT_ADDR: ${VAULT_ADDR}"
vault login ${vault_token}
#export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
#vault login s.1pVzz8zXNCfdjegj0cfrkdDT


vault write ssh-client-signer/roles/one_minute -<<"EOH"
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": [
    {
      "permit-pty": ""
    }
  ],
  "key_type": "ca",
  "default_user": "root",
  "ttl": "1m0s"
}
EOH

vault write ssh-client-signer/roles/one_day -<<"EOH"
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": [
    {
      "permit-pty": ""
    }
  ],
  "key_type": "ca",
  "default_user": "root",
  "ttl": "24h"
}
EOH

vault write ssh-client-signer/roles/one_week -<<"EOH"
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": [
    {
      "permit-pty": ""
    }
  ],
  "key_type": "ca",
  "default_user": "root",
  "ttl": "168h"
}
EOH

vault write ssh-client-signer/roles/one_month -<<"EOH"
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": [
    {
      "permit-pty": ""
    }
  ],
  "key_type": "ca",
  "default_user": "root",
  "ttl": "744h"
}
EOH

vault write ssh-client-signer/roles/one_year -<<"EOH"
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": [
    {
      "permit-pty": ""
    }
  ],
  "key_type": "ca",
  "default_user": "root",
  "ttl": "8760h"
}
EOH
