#!/usr/bin/env bash

source /root/.bashrc
#bash /vagrant/tz-local/resource/vault/external-secrets/install.sh
cd /vagrant/tz-local/resource/vault/external-secrets

AWS_REGION=$(prop 'config' 'region')
eks_domain=$(prop 'project' 'domain')
eks_project=$(prop 'project' 'project')
vault_token=$(prop 'project' 'vault')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)
NS=external-secrets

helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm uninstall external-secrets -n ${NS}
#--reuse-values
helm upgrade --debug --install external-secrets \
   external-secrets/external-secrets \
    -n ${NS} \
    --create-namespace \
    --set installCRDs=true

#aws_access_key_id=$(prop 'credentials' 'aws_access_key_id' ${eks_project})
#aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key' ${eks_project})
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id')
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key')

echo -n ${aws_access_key_id} > ./access-key
echo -n ${aws_secret_access_key} > ./secret-access-key
kubectl -n ${NS} delete secret awssm-secret
kubectl -n ${NS} create secret generic awssm-secret --from-file=./access-key  --from-file=./secret-access-key

rm -Rf ./access-key ./secret-access-key

#export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
#vault login ${vault_token}
#vault kv get secret/devops-prod/dbinfo

#PROJECTS=(devops devops-dev)
PROJECTS=(default argocd devops devops-dev)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    STAGING="dev"
    if [[ "${item/*-dev/}" == "" ]]; then
      project=${item/-prod/}
      STAGING="dev"
      namespace=${project}
    else
      project=${item}-prod
      project_qa=${item}-qa
      STAGING="prod"
      namespace=${item}
    fi
    echo "=====================STAGING: ${STAGING}"
echo '
apiVersion: v1
kind: ServiceAccount
metadata:
  name: PROJECT-svcaccount
  namespace: "NAMESPACE"
---

apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: "PROJECT"
  namespace: "NAMESPACE"
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "PROJECT"
          serviceAccountRef:
            name: "PROJECT-svcaccount"
' > secret.yaml

    cp secret.yaml secret.yaml_bak
    sed -i "s|PROJECT|${project}|g" secret.yaml_bak
    sed -i "s|NAMESPACE|${namespace}|g" secret.yaml_bak
    kubectl apply -f secret.yaml_bak

    if [ "${STAGING}" == "prod" ]; then
      cp secret.yaml secret.yaml_bak
      sed -i "s|PROJECT|${project_qa}|g" secret.yaml_bak
      sed -i "s|NAMESPACE|${namespace}|g" secret.yaml_bak
      kubectl apply -f secret.yaml_bak
    fi
  fi
done

rm -Rf secret.yaml secret.yaml_bak

kubectl apply -f test.yaml
kubectl -n devops describe externalsecret devops-externalsecret
kubectl get SecretStores,ClusterSecretStores,ExternalSecrets --all-namespaces

exit 0
