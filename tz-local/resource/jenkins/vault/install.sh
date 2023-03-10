#!/usr/bin/env bash

# https://codeburst.io/read-vaults-secrets-from-jenkin-s-declarative-pipeline-50a690659d6
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

export VAULT_ADDR=http://vault.default.eks-main-t.tzcorp.com
#export VAULT_ADDR=http://vault.vault.svc.cluster.local
#export VAULT_ADDR=https://vault.default.${eks_project}.${eks_domain}
vault login ${vault_token}

# Enable approle on vault
vault auth enable approle
# Make sure a v2 kv secrets engine enabled:
vault secrets enable kv-v2
# Upgrading from Version 1 if you needit
vault kv enable-versioning secret/

# Create jenkins policy
#vault policy write jenkins jenkins-policy.hcl
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

https://jenkins.default.eks-main-t.tzcorp.com/manage/configure
Vault URL: http://vault.vault.svc.cluster.local:8200
  Add Credentials
    Vault App Role Credential
      Role ID: 06e1f9bf-xxx
      Secret ID: 4b59eaa2-xxx
      ID: vault-approle

# bastion
kubectl apply -f ubuntu.yaml -n jenkins
apt update && apt install wget unzip -y
wget https://releases.hashicorp.com/vault/1.3.1/vault_1.3.1_linux_amd64.zip
unzip vault_1.3.1_linux_amd64.zip
rm -Rf vault_1.3.1_linux_amd64.zip
mv vault /usr/local/bin/
vault -autocomplete-install
complete -C /usr/local/bin/vault vault


kubectl -n jenkins exec -it pod/bastion -- sh
AWS_REGION=us-west-1
ECR_REGISTRY="746446553436.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "{\"credHelpers\":{\"$ECR_REGISTRY\":\"ecr-login\"}}" > /root/.docker/config2.json

/kaniko/executor
--context "${CI_PROJECT_DIR}"
--dockerfile "${CI_PROJECT_DIR}/Dockerfile"
--destination "${CI_REGISTRY_IMAGE}:${CI_COMMIT_TAG}"
