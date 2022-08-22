#!/usr/bin/env bash

#https://learn.hashicorp.com/tutorials/vault/agent-kubernetes?in=vault/kubernetes
#https://www.hashicorp.com/blog/injecting-vault-secrets-into-kubernetes-pods-via-a-sidecar
#https://www.vaultproject.io/docs/platform/k8
# s/injector

#bash /vagrant/tz-local/resource/vault/vault-injection/update.sh
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

vault list auth/kubernetes/role

#bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh default
kubectl get csr -o name | xargs kubectl certificate approve

PROJECTS=($(kubectl get namespaces | awk '{print $1}' | tr '\n' ' '))
#PROJECTS=(devops-dev devops-prod)
for item in "${PROJECTS[@]}"; do
  echo "====================="
  echo ${item}
  accounts="default"
  namespaces="default"

  if [[ "${item/*-dev/}" == "" ]]; then
    echo "=====================dev"
    project=${item}
    accounts=${accounts},${item}-svcaccount
    namespaces=${namespaces},${item}  # devops-dev
  else
    echo "=====================prod"
    project=${item}-prod
    accounts=${accounts},${item}-dev-svcaccount,${project}-svcaccount # devops-dev devops-prod
    namespaces=${namespaces},${project}-dev,${project}  # devops-dev devops
  fi
#  for value in "${accounts[@]}"; do
#     echo $value
#  done
#  for value in "${namespaces[@]}"; do
#     echo $value
#  done
  if [[ -f /vagrant/tz-local/resource/vault/data/${project}.hcl ]]; then
    vault write auth/kubernetes/role/${project} \
            bound_service_account_names=${accounts} \
            bound_service_account_namespaces=${namespaces} \
            policies=tz-vault-${project} \
            ttl=24h
    vault policy write tz-vault-${project} /vagrant/tz-local/resource/vault/data/${project}.hcl
    vault kv put secret/${project}/dbinfo name='localhost' passwod=1111 ttl='30s'
    vault kv put secret/${project}/foo name='localhost' passwod=1111 ttl='30s'
    vault read auth/kubernetes/role/${project}
  fi
done

exit 0
