#!/usr/bin/env bash

source /root/.bashrc
#bash /vagrant/tz-local/resource/vault/helm/install.sh
cd /vagrant/tz-local/resource/vault/helm

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id')
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key')
vault_kms_key=$(aws kms list-aliases | grep -w "${eks_project}-vault-kms-unseal_04" -A 1 | tail -n 1 | awk -F\" '{print $4}')
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

kubectl -n vault delete secret generic eks-creds
kubectl -n vault create secret generic eks-creds \
    --from-literal=AWS_ACCESS_KEY_ID="${aws_access_key_id}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${aws_secret_access_key}"

bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh vault

cp -Rf values_cert.yaml values_cert.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values_cert.yaml_bak
sed -i "s/AWS-REGION/${AWS_REGION}/g" values_cert.yaml_bak
sed -i "s/VAULT_KMS_KEY/${vault_kms_key}/g" values_cert.yaml_bak
helm upgrade --debug --install --reuse-values vault hashicorp/vault -n vault -f values_cert.yaml_bak --version 0.19.0
#kubectl rollout restart statefulset.apps/vault -n vault

sleep 30
k get all -n vault

cp -Rf values_config.yaml values_config.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values_config.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" values_config.yaml_bak
sed -i "s/AWS-REGION/${AWS_REGION}/g" values_config.yaml_bak
sed -i "s/VAULT_KMS_KEY/${vault_kms_key}/g" values_config.yaml_bak
k apply -f values_config.yaml_bak -n vault

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
vault_token_new=$(cat /vagrant/resources/unseal.txt | grep "Initial Root Token:" | tail -n 1 | awk '{print $4}')
echo "#######################################################"
echo "vault_token_new: ${vault_token_new}"
echo "#######################################################"
if [[ "${vault_token_new}" != "" ]]; then
  awk '!/vault=/' /vagrant/resources/project > tmpfile && mv tmpfile /vagrant/resources/project
  echo "vault=${vault_token_new}" >> /vagrant/resources/project
  cp -Rf /vagrant/resources/project ~/.aws/project
  cp -Rf /vagrant/resources/project /home/vagrant/.aws/project
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

cp -Rf values_config.yaml values_config.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values_config.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" values_config.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" values_config.yaml_bak
sed -i "s/VAULT_KMS_KEY/${vault_kms_key}/g" values_config.yaml_bak
k apply -f values_config.yaml_bak -n vault

sleep 30
# to NodePort

k -n vault get pods -l app.kubernetes.io/name=vault

#curl http://dooheehong323:31700/ui/vault/secrets

VAULT_VERSION="1.3.1"
curl -sO https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
rm -Rf vault_${VAULT_VERSION}_linux_amd64.zip
mv vault /usr/local/bin/
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
region=ap-southeast-1


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

# backup and restore
export CONSUL_HTTP_ADDR="consul.default.${eks_project}.${eks_domain}"
consul members

consul snapshot save backup.snap
vault operator raft snapshot save backup.snap
vault operator raft snapshot restore -force backup.snap

#######################################################################
" >> /vagrant/info
cat /vagrant/info

exit 0

