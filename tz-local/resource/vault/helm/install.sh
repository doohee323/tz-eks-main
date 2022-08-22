#!/usr/bin/env bash

### https://lejewk.github.io/vault-get-started/
### https://www.udemy.com/course/hashicorp-vault/learn/lecture/17017040#overview
### https://github.com/btkrausen/hashicorp

#bash /vagrant/tz-local/resource/vault/helm/install.sh
cd /vagrant/tz-local/resource/vault/helm

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
vault_kms_key=$(aws kms list-aliases | grep -w "${eks_project}-vault-kms-unseal4" -A 1 | tail -n 1 | awk -F\" '{print $4}')
vault_token=$(prop 'project' 'vault')
NS=vault

echo "#######################################################"
echo "vault_kms_key: ${vault_kms_key}"
echo "#######################################################"
if [[ "${vault_kms_key}" == "" ]]; then
  echo "kms is empty!!!!"
  exit 1
fi

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/vault

helm uninstall vault -n vault
k delete namespace vault
k create namespace vault

kubectl -n vault create secret generic eks-creds \
    --from-literal=AWS_ACCESS_KEY_ID="${aws_access_key_id}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${aws_secret_access_key}"

bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh vault

cp -Rf values_cert.yaml values_cert.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values_cert.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" values_cert.yaml_bak
sed -i "s/VAULT_KMS_KEY/${vault_kms_key}/g" values_cert.yaml_bak
helm upgrade --debug --install --reuse-values vault hashicorp/vault -n vault -f values_cert.yaml_bak --version 0.19.0
#kubectl rollout restart statefulset.apps/vault -n vault

sleep 30
k get all -n vault

cp -Rf values_config.yaml values_config.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values_config.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" values_config.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" values_config.yaml_bak
sed -i "s/VAULT_KMS_KEY/${vault_kms_key}/g" values_config.yaml_bak
k apply -f values_config.yaml_bak -n vault
#k patch statefulset/vault -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n vault
#k patch statefulset/vault -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "consul"}}}}}' -n vault
#k patch statefulset/vault -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n vault

sleep 30
# to NodePort

#k patch svc vault-standby --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":31700}]' -n vault
cp -Rf ingress-vault.yaml ingress-vault.yaml_bak
sed -i "s/eks_project/${eks_project}/g" ingress-vault.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" ingress-vault.yaml_bak
sed -i "s|NS|${NS}|g" ingress-vault.yaml_bak
k delete -f ingress-vault.yaml_bak -n vault
k apply -f ingress-vault.yaml_bak -n vault

sleep 30

#k port-forward vault-0 8200:8200 -n vault &
k get pods -l app.kubernetes.io/name=vault -n vault

sleep 30
# vault operator init
# vault operator init -key-shares=3 -key-threshold=2
#export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_ADDR="http://vault.default.${eks_project}.${eks_domain}"
echo $VAULT_ADDR
k -n vault exec -ti vault-0 -- vault operator init -key-shares=3 -key-threshold=2 | sed 's/\x1b\[[0-9;]*m//g' > /vagrant/resources/unseal.txt
sleep 20
vault_token_new=$(cat /vagrant/resources/unseal.txt | grep "Initial Root Token:" | awk '{print $4}')
vault_token_new=$(echo ${vault_token_new} | rev | cut -c2- | rev)
echo "#######################################################"
echo "vault_token_new: ${vault_token_new}"
echo "#######################################################"
if [[ "${vault_token_new}" != "" ]]; then
  sed -i "s/${vault_token}/${vault_token_new}/g" /vagrant/resources/project
  sed -i "s/${vault_token}/${vault_token_new}/g" ~/.aws/project
  sed -i "s/${vault_token}/${vault_token_new}/g" /home/vagrant/.aws/project
fi

# vault operator unseal
#echo k -n vault exec -ti vault-0 -- vault operator unseal
#k -n vault exec -ti vault-0 -- vault operator unseal # ... Unseal Key 1
#k -n vault exec -ti vault-0 -- vault operator unseal # ... Unseal Key 2,3,4,5
#
#echo k -n vault exec -ti vault-1 -- vault operator unseal
#k -n vault exec -ti vault-1 -- vault operator unseal # ... Unseal Key 1
#k -n vault exec -ti vault-1 -- vault operator unseal # ... Unseal Key 2,3,4,5
#
#echo k -n vault exec -ti vault-2 -- vault operator unseal
#k -n vault exec -ti vault-2 -- vault operator unseal # ... Unseal Key 1
#k -n vault exec -ti vault-2 -- vault operator unseal # ... Unseal Key 2,3,4,5

k -n vault get pods -l app.kubernetes.io/name=vault

#curl http://dooheehong323:31700/ui/vault/secrets

VAULT_VERSION="1.3.1"
curl -sO https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
rm -Rf vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
vault --version

#vault -autocomplete-install
#complete -C /usr/local/bin/vault vault
#vault -h

echo "
##[ Vault ]##########################################################
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login ${vault_token_new}

vault secrets list -detailed

vault kv list kv
vault kv put kv/my-secret my-value=yea
vault kv get kv/my-secret

vault kv put kv/tz-vault tz-value=yes
vault kv get kv/tz-vault

vault kv delete kv/tz-vault

vault kv metadata get kv/tz-vault
vault kv metadata delete kv/tz-vault


# aws key
vault secrets enable aws

vault write aws/config/root \
access_key=AKIAW354R7YB6TQ7LZVA \
secret_key=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 \
region=us-west-1


#vault secrets enable -path=kv kv

# macos
brew tap hashicorp/tap
brew install hashicorp/tap/vault
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login s.qBPblA0U9Bzmhgr8eRnukSqR
vault secrets list -detailed

vault audit enable file file_path=/home/vagrant/tmp/a.log

# path ex)
secrets
  apps
    app1_web
    app1_demon
  common
    api_key

#######################################################################
" >> /vagrant/info
cat /vagrant/info

exit 0




cat <<EOF | sudo tee /etc/vault/config.hcl
disable_cache = true
disable_mlock = true
ui = true
api_addr         = "http://0.0.0.0:8200"
listener "tcp" {
   address          = "0.0.0.0:8200"
   tls_disable      = 1
}
storage "file" {
   path  = "/var/lib/vault/data"
}
max_lease_ttl         = "10h"
default_lease_ttl    = "10h"
cluster_name         = "vault"
raw_storage_endpoint     = true
disable_sealwrap     = true
disable_printable_check = true
EOF

# production ex)
cat <<EOF | sudo tee /etc/vault/config.hcl
storage "consul" {
    path = "vault"
    address = "localhost:8500"
}
listener "tcp" {
   address          = "0.0.0.0:8200"
   cluster_address  = "0.0.0.0:8201"
   tls_cert_file    = "/etc/certs/vault.crt"
   tls_cert_key     = "/etc/certs/vault.key"
}
seal "awskms" {
  region = "us-west-02"
  kms_key_id = "aaaaaaa"
}
api_addr            = "http://0.0.0.0:8200"
ui = true
cluster_name        = "tz-vault"
log_level           = "info"

disable_cache = true
disable_mlock = true
max_lease_ttl       = "10h"
default_lease_ttl   = "10h"
raw_storage_endpoint = true
disable_sealwrap     = true
disable_printable_check = true
EOF


kubectl create secret generic vault-storage-config \
    --from-file=/etc/vault/config.hcl


# auto unseal
# https://blogs.halodoc.io/vault-auto-unseal-via-aws-kms/


k patch deployment/vault-agent-injector -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n vault
k patch deployment/vault-agent-injector -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "consul"}}}}}' -n vault
k patch deployment/vault-agent-injector -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n vault
