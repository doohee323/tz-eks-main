#!/usr/bin/env bash

#https://learn.hashicorp.com/tutorials/vault/agent-kubernetes?in=vault/kubernetes
#https://www.hashicorp.com/blog/injecting-vault-secrets-into-kubernetes-pods-via-a-sidecar
#https://www.vaultproject.io/docs/platform/k8
# s/injector

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

vault write auth/kubernetes/role/twip-prod \
        bound_service_account_names=twip-prod-svcaccount \
        bound_service_account_namespaces=twip \
        policies=tz-vault-twip-prod \
        ttl=24h

vault list auth/kubernetes/role
vault read auth/kubernetes/role/twip-prod

exit 0

#cat /var/run/secrets/kubernetes.io/serviceaccount/token

#kubectl -n vault delete pod/tmp
#kubectl -n vault run tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7
#kubectl -n vault exec -it pod/tmp -- sh
#apk update
#apk add curl jq

export VAULT_ADDR="https://vault.default.${eks_project}.${eks_domain}"
#export VAULT_ADDR=http://10.20.4.13:8200
#export SA_JWT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

curl -s $VAULT_ADDR/v1/sys/seal-status | jq

curl -s --request POST \
        --data '{"jwt": "'"$SA_JWT_TOKEN"'", "role": "devops-dev"}' \
        $VAULT_ADDR/v1/auth/kubernetes/login | jq

cd /vagrant/tz-local/resource/vault/vault-injection

vault policy write tz-vault-devops-dev /vagrant/tz-local/resource/vault/data/devops-dev.hcl
vault kv put secret/devops-dev/dbinfo type=mysql name=testdb host=localhost port=2222 passwod=1111 ttl='30s'
vault kv put secret/devops-dev/foo name=testdb2 passwod=2222 ttl='30s'

#vault policy write tz-vault-open /vagrant/tz-local/resource/vault/data/open.hcl
#vault policy write tz-vault-devops-dev /vagrant/tz-local/resource/vault/data/devops-dev.hcl
kubectl delete -f vault-demo.yaml -n vault
kubectl apply -f vault-demo.yaml -n vault
vault write auth/kubernetes/role/vault-agent-demo-role \
        bound_service_account_names=vault-agent-demo-account \
        bound_service_account_namespaces=vault \
        policies=tz-vault-devops-dev \
        ttl=24h
vault read auth/kubernetes/role/vault-agent-demo-role

kubectl -n vault patch deployment vault-agent-demo --patch "$(cat patch.yaml)"
sleep 10
kubectl -n vault exec -ti $(kubectl -n vault get all | grep pod/vault-agent-demo-) -c vault-agent-demo -- ls -l /vault/secrets

kubectl delete -f vault-demo2.yaml -n vault
kubectl apply -f vault-demo2.yaml -n vault
vault write auth/kubernetes/role/vault-agent-demo2-role \
        bound_service_account_names=vault-agent-demo2-account \
        bound_service_account_namespaces=vault \
        policies=tz-vault-devops-dev \
        ttl=24h

exit 0

vault policy write tz-vault-twip /vagrant/tz-local/resource/vault/data/twip.hcl
vault kv put secret/twip/database type=mysql name=testdb host=localhost port=2222 passwod=1111 ttl='30s'
kubectl delete -f app-twip-dev.yaml -n twip-dev
kubectl apply -f app-twip-dev.yaml -n twip-dev
vault write auth/kubernetes/role/twip-dev \
        bound_service_account_names=twip-dev-svcaccount \
        bound_service_account_namespaces=twip-dev \
        policies=tz-vault-twip \
        ttl=24h
kubectl -n twip-dev exec -ti $(kubectl -n twip-dev get all | grep pod/vault-demo-) -c vault-demo -- ls -l /vault/secrets

kubectl delete -f app-twip.yaml -n twip
kubectl apply -f app-twip.yaml -n twip
vault write auth/kubernetes/role/twip \
        bound_service_account_names=twip-svcaccount \
        bound_service_account_namespaces=twip \
        policies=tz-vault-twip \
        ttl=24h

vault policy write tz-vault-twip /vagrant/tz-local/resource/vault/data/twip.hcl
vault kv put secret/twip/database host='https://tz-internal.mytwip.net/api/log_campaign_engagement' passwod=1111 ttl='30s'
kubectl delete -f k8s.yaml -n twip-dev
kubectl apply -f k8s.yaml -n twip-dev
vault write auth/kubernetes/role/twip-dev \
        bound_service_account_names=twip-dev-svcaccount \
        bound_service_account_namespaces=twip-dev \
        policies=tz-vault-twip \
        ttl=24h

kubectl -n vault run tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7

kubectl -n vault exec -it pod/tmp -- sh
apk update
apk add curl jq
SA_JWT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

curl -s $VAULT_ADDR/v1/sys/seal-status | jq

curl --request POST \
        --data '{"jwt": "'"$SA_JWT_TOKEN"'", "role": "devops-dev"}' \
        $VAULT_ADDR/v1/auth/kubernetes/login | jq

curl -s --request POST \
    --data '{"jwt": "'"$SA_JWT_TOKEN"'", "role": "devops-dev"}' \
    $VAULT_ADDR/v1/auth/kubernetes/login | jq




####################################################################################
# auto-auth.yaml
####################################################################################

kubectl -n vault create -f auto-auth.yaml
kubectl -n vault apply -f auto-auth-pod.yaml --record


kubectl run -it busybox --image=ubuntu:16.04 -n vault -- sh
apt update
apt install netcat curl iputils-ping telnet -y

export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
telnet vault.vault.svc.cluster.local 8200
telnet vault.vault.svc.cluster.local 8201




exit 0


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

vault kv put secret/twip-dev/foo name='localhost2' \
  passwod='222' \
  ttl='30s'

vault kv get secret/twip-dev/foo

# install vault in pod
wget https://releases.hashicorp.com/vault/1.3.1/vault_1.3.1_linux_amd64.zip
unzip vault_1.3.1_linux_amd64.zip
rm -Rf vault_1.3.1_linux_amd64.zip
mv vault /usr/local/bin/
vault -autocomplete-install
complete -C /usr/local/bin/vault vault

# Vault Injection debugging for datateam (jupyterhub-hub)
# https://tzcorp.atlassian.net/wiki/spaces/DEV/pages/560202152/Vault+Injection+debugging+for+datateam+jupyterhub-hub
export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
vault login -method=userpass username=ec.song
Password (will be hidden):
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
~
token_policies         ["default" "tz-vault-datateam-dev" "tz-vault-datateam-prod" "tz-vault-userpass" "read-role"]
identity_policies      []
policies               ["default" "tz-vault-datateam-dev" "tz-vault-datateam-prod" "tz-vault-userpass" "read-role"]
token_meta_username    ec.song

vault kv get secret/datateam-dev/deployment/jupyterhub

vault login xxxx

# add jupyterhub-hub !!!
#  serviceAccountName: jupyterhub-hub
#  serviceAccount: jupyterhub-hub
#  nodeName: ip-10-20-3-14.us-west-2.compute.internal
#  securityContext:
vault write auth/kubernetes/role/datateam-dev \
        bound_service_account_names=datateam-dev-svcaccount,jupyterhub-hub \
        bound_service_account_namespaces=datateam-dev \
        policies=tz-vault-datateam-dev \
        ttl=24h

vault write auth/userpass/users/ec.song password=ec.song \
        policies=read-role,tz-vault-datateam-dev,tz-vault-datateam-prod,tz-vault-userpass











