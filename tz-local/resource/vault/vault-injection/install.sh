#!/usr/bin/env bash

source /root/.bashrc
#bash /vagrant/tz-local/resource/vault/vault-injection/install.sh
cd /vagrant/tz-local/resource/vault/vault-injection

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
VAULT_TOKEN=$(prop 'project' 'vault')
AWS_REGION=$(prop 'config' 'region')

export VAULT_ADDR="https://vault.default.${eks_project}.${eks_domain}"
vault login ${VAULT_TOKEN}

curl -s ${VAULT_ADDR}/v1/sys/seal-status | jq
EXTERNAL_VAULT_ADDR="https://vault.default.${eks_project}.${eks_domain}"
echo $EXTERNAL_VAULT_ADDR

bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh
kubectl get csr -o name | xargs kubectl certificate approve

vault secrets enable -path=secret/ kv
vault auth enable kubernetes

#kubectl -n vault create serviceaccount vault-auth
cp -Rf vault-auth-service-account.yaml vault-auth-service-account.yaml_bak
sed -i "s/namespace: vault/namespace: vault/g" vault-auth-service-account.yaml_bak
kubectl -n vault delete -f vault-auth-service-account.yaml_bak
kubectl -n vault create -f vault-auth-service-account.yaml_bak
kubectl -n vault create -f vault-auth-service-account2.yaml
# Prepare kube api server data
export VAULT_SA_NAME=$(kubectl -n vault get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl -n vault get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export K8S_HOST="$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')"
export SA_CA_CRT="$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)"

echo "VAULT_SA_NAME: ${VAULT_SA_NAME}"
echo "SA_JWT_TOKEN: ${SA_JWT_TOKEN}"
echo "K8S_HOST: ${K8S_HOST}"
echo "SA_CA_CRT: ${SA_CA_CRT}"

vault secrets enable -path=secret/ kv
vault auth enable kubernetes
vault write auth/kubernetes/config \
        token_reviewer_jwt="${SA_JWT_TOKEN}" \
        kubernetes_host="${K8S_HOST}" \
        kubernetes_ca_cert="${SA_CA_CRT}" \
        issuer="https://kubernetes.default.svc.cluster.local"
#        disable_iss_validation=true

export VAULT_ADDR="https://vault.default.${eks_project}.${eks_domain}"
#export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
#vault write auth/userpass/users/doogee323 password=1111111 policies=tz-vault-devops
vault login -method=userpass username=doogee323

## ********* in vault pod *********
#VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
#vault login s.H7TwKTLuJmBx0UgAg5aAeGMN
#vault write auth/kubernetes/config
#    kubernetes_host="${K8S_API_SERVER}"
#    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
#    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault read auth/kubernetes/config

vault write auth/kubernetes/role/devops-prod \
        bound_service_account_names=devops-prod-svcaccount \
        bound_service_account_namespaces=devops \
        policies=tz-vault-devops-prod \
        ttl=24h

vault list auth/kubernetes/role
vault read auth/kubernetes/role/devops-prod

exit 0
