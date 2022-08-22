#!/usr/bin/env bash

#https://learn.hashicorp.com/tutorials/vault/agent-kubernetes?in=vault/kubernetes
#https://www.hashicorp.com/blog/injecting-vault-secrets-into-kubernetes-pods-via-a-sidecar
#https://www.vaultproject.io/docs/platform/k8
# s/injector

#bash /vagrant/tz-local/resource/vault/vault-injection/install.sh
cd /vagrant/tz-local/resource/vault/vault-injection

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
VAULT_TOKEN=$(prop 'project' 'vault')
AWS_REGION=$(prop 'config' 'region')

export VAULT_ADDR="http://vault.default.${eks_project}.${eks_domain}"
vault login ${VAULT_TOKEN}

curl -s ${VAULT_ADDR}/v1/sys/seal-status | jq
EXTERNAL_VAULT_ADDR="http://vault.default.${eks_project}.${eks_domain}"
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
# Prepare kube api server data
export SECRET_NAME="$(kubectl -n vault get serviceaccount vault-auth  -o go-template='{{ (index .secrets 0).name }}')"
export TR_ACCOUNT_TOKEN="$(kubectl -n vault get secret ${SECRET_NAME} -o go-template='{{ .data.token }}' | base64 --decode)"
export K8S_API_SERVER="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"server\" }}{{ end }}")"
export K8S_CACERT="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"certificate-authority-data\" }}{{ end }}" | base64 --decode)"
echo "SECRET_NAME: ${SECRET_NAME}"
echo "TR_ACCOUNT_TOKEN: ${TR_ACCOUNT_TOKEN}"
echo "K8S_API_SERVER: ${K8S_API_SERVER}"
echo "K8S_CACERT: ${K8S_CACERT}"

# Send kube config to vault
vault write auth/kubernetes/config \
        kubernetes_host="${K8S_API_SERVER}"
        kubernetes_ca_cert="${K8S_CACERT}"
        token_reviewer_jwt="${TR_ACCOUNT_TOKEN}"

vault write auth/kubernetes/role/devops-dev \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=vault \
        policies=tz-vault-devops-dev \
        ttl=24h

vault list auth/kubernetes/role
vault read auth/kubernetes/role/devops-dev

exit 0

#cat /var/run/secrets/kubernetes.io/serviceaccount/token

#kubectl -n vault delete pod/tmp
#kubectl -n vault run tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7
#kubectl -n vault exec -it pod/tmp -- sh
#apk update
#apk add curl jq

export VAULT_ADDR="http://vault.default.${eks_project}.${eks_domain}"
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

vault policy write tz-vault-devops /vagrant/tz-local/resource/vault/data/devops.hcl
vault kv put secret/devops/database type=mysql name=testdb host=localhost port=2222 passwod=1111 ttl='30s'
kubectl delete -f app-devops-dev.yaml -n devops-dev
kubectl apply -f app-devops-dev.yaml -n devops-dev
vault write auth/kubernetes/role/devops-dev \
        bound_service_account_names=devops-dev-svcaccount \
        bound_service_account_namespaces=devops-dev \
        policies=tz-vault-devops \
        ttl=24h
kubectl -n devops-dev exec -ti $(kubectl -n devops-dev get all | grep pod/vault-demo-) -c vault-demo -- ls -l /vault/secrets

kubectl delete -f app-devops.yaml -n devops
kubectl apply -f app-devops.yaml -n devops
vault write auth/kubernetes/role/devops \
        bound_service_account_names=devops-svcaccount \
        bound_service_account_namespaces=devops \
        policies=tz-vault-devops \
        ttl=24h

vault policy write tz-vault-devops /vagrant/tz-local/resource/vault/data/devops.hcl
vault kv put secret/devops/database host='https://tz-internal.mydevops.net/api/log_campaign_engagement' passwod=1111 ttl='30s'
kubectl delete -f k8s.yaml -n devops-dev
kubectl apply -f k8s.yaml -n devops-dev
vault write auth/kubernetes/role/devops-dev \
        bound_service_account_names=devops-dev-svcaccount \
        bound_service_account_namespaces=devops-dev \
        policies=tz-vault-devops \
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
export SA_CA_CRT=$(kubectl -n vault get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
export K8S_HOST=$(terraform output | grep 'cluster_endpoint' |  cut -d '=' -f2 | sed 's/ //g')
echo "K8S_HOST: ${K8S_HOST}"
echo "SA_JWT_TOKEN: ${SA_JWT_TOKEN}"
echo "SA_CA_CRT: ${SA_CA_CRT}"
popd

vault secrets enable -path=secret/ kv
vault auth enable kubernetes
vault write auth/kubernetes/config \
        token_reviewer_jwt="$SA_JWT_TOKEN" \
        kubernetes_host="$K8S_HOST" \
        kubernetes_ca_cert="$SA_CA_CRT" \
        issuer="https://kubernetes.default.svc.cluster.local"
#        disable_iss_validation=true
