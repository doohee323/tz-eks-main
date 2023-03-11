#!/usr/bin/env bash

#https://piotrminkowski.com/2022/08/08/manage-secrets-on-kubernetes-with-argocd-and-vault/

source /root/.bashrc
#bash /vagrant/tz-local/resource/argocd/helm/install.sh
cd /vagrant/tz-local/resource/argocd/helm

#set -x
shopt -s expand_aliases

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
admin_password=$(prop 'project' 'admin_password')
github_token=$(prop 'project' 'github_token')
basic_password=$(prop 'project' 'basic_password')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

alias k='kubectl --kubeconfig ~/.kube/config'
#alias k="kubectl --kubeconfig ~/.kube/kubeconfig_${eks_project}"

k delete namespace argocd
k create namespace argocd

#################################################################################
# 1) install argocd
#################################################################################
helm repo add argo https://argoproj.github.io/argo-helm
helm uninstall argocd argo/argo-cd -n argocd

#  AVP_AUTH_TYPE: azhz    k8s
#  AVP_K8S_MOUNT_PATH: YXV0aC9rdWJlcm5ldGVz   auth/kubernetes
#  AVP_K8S_ROLE: azhz   k8s
#  AVP_TYPE: dmF1bHQ=   vault
#  VAULT_ADDR: aHR0cDovL3ZhdWx0LnZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsOjgyMDA=     http://vault.vault.svc.cluster.local:8200
kubectl -n argocd delete -f argocd-installation/argocd-vault-plugin-credentials.yaml
kubectl -n argocd apply -f argocd-installation/argocd-vault-plugin-credentials.yaml
helm upgrade --debug --install --reuse-values argocd argo/argo-cd \
  -n argocd -f argocd-installation/argocd-helm-values.yaml --version 5.20.4

#  AVP_AUTH_TYPE: azhz    k8s
#  AVP_K8S_MOUNT_PATH: YXV0aC9rdWJlcm5ldGVz   auth/kubernetes
#  AVP_K8S_ROLE: azhz   k8s
#  AVP_TYPE: dmF1bHQ=   vault
#  VAULT_ADDR: aHR0cDovL3ZhdWx0LnZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsOjgyMDA=     http://vault.vault.svc.cluster.local:8200
kubectl -n argocd delete -f argocd-installation/argocd-vault-plugin-cmp.yaml
kubectl -n argocd apply -f argocd-installation/argocd-vault-plugin-cmp.yaml

k patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 120
TMP_PASSWORD=$(k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "############################################"
echo "TMP_PASSWORD: ${TMP_PASSWORD}"
echo "############################################"

#VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
#sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
#sudo chmod +x /usr/local/bin/argocd
#brew tap argoproj/tap
#brew install argoproj/tap/argocd
#argocd

argocd login `k get service -n argocd | grep -w "argocd-server " | awk '{print $4}'` --username admin --password ${TMP_PASSWORD} --insecure
argocd account update-password --account admin --current-password ${TMP_PASSWORD} --new-password ${admin_password}

# basic auth
#https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
#https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
#echo ${basic_password} | htpasswd -i -n admin > auth
#k create secret generic basic-auth-argocd --from-file=auth -n argocd
#k get secret basic-auth-argocd -o yaml -n argocd
#rm -Rf auth

cp -Rf ingress-argocd.yaml ingress-argocd.yaml_bak
sed -i "s/eks_project/${eks_project}/g" ingress-argocd.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" ingress-argocd.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" ingress-argocd.yaml_bak
k delete -f ingress-argocd.yaml_bak -n argocd
k apply -f ingress-argocd.yaml_bak -n argocd

k patch deploy/argocd-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
k patch deploy/argocd-applicationset-controller -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
k patch deploy/argocd-redis -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
k patch deploy/argocd-notifications-controller -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
k patch deploy/argocd-repo-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
k patch deploy/argocd-dex-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
k patch deploy/argocd-redis -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n argocd

argocd login `k get service -n argocd | grep argocd-server | awk '{print $4}' | head -n 1` --username admin --password ${admin_password} --insecure
argocd repo add https://github.com/tzkr/tz-argocd-repo \
  --username devops-tz --password ${github_token}

kubectl config get-contexts
#CURRENT   NAME             CLUSTER          AUTHINFO         NAMESPACE
#          eks_eks-main-p   eks_eks-main-p   eks_eks-main-p
#*         eks_eks-main-t   eks_eks-main-t   eks_eks-main-t
argocd cluster add --yes eks_eks-main-p

bash /vagrant/tz-local/resource/argocd/update.sh
bash /vagrant/tz-local/resource/argocd/update.sh

#################################################################################
# 2) integrate with vault
#################################################################################
export VAULT_ADDR="https://vault.default.${eks_project}.${eks_domain}"
echo "VAULT_ADDR: ${VAULT_ADDR}"
vault login ${vault_token}
vault auth enable kubernetes

cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-repo-server
subjects:
  - kind: ServiceAccount
    name: argocd-repo-server
    namespace: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-repo-server
EOF

# Prepare kube api server data
export SECRET_NAME="$(kubectl -n argocd get serviceaccount argocd-repo-server -o go-template='{{ (index .secrets 0).name }}')"
export TR_ACCOUNT_TOKEN="$(kubectl -n argocd get secret ${SECRET_NAME} -o go-template='{{ .data.token }}' | base64 --decode)"
export K8S_API_SERVER="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"server\" }}{{ end }}")"
export K8S_CACERT="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"certificate-authority-data\" }}{{ end }}" | base64 --decode)"
echo "SECRET_NAME: ${SECRET_NAME}"
echo "TR_ACCOUNT_TOKEN: ${TR_ACCOUNT_TOKEN}"
echo "K8S_API_SERVER: ${K8S_API_SERVER}"
echo "K8S_CACERT: ${K8S_CACERT}"

# Send kube config to vault
vault write auth/kubernetes/config \
  kubernetes_host="${K8S_API_SERVER}" \
  kubernetes_ca_cert="${K8S_CACERT}" \
  token_reviewer_jwt="${TR_ACCOUNT_TOKEN}"

vault read auth/kubernetes/config

vault policy write k8s - <<EOF
path "secret/*" {
  capabilities = ["list", "read"]
}
EOF
vault write auth/kubernetes/role/k8s \
  bound_service_account_names=argocd-repo-server \
  bound_service_account_namespaces=* \
  policies=default,k8s ttl=15m

#################################################################################
# 3) verify access to vault from argocd-repo-server
#################################################################################
TOKEN_REVIEW_SJWT=$(kubectl -n argocd get secret ${SECRET_NAME} -o go-template='{{ .data.token }}' | base64 --decode)

kubectl -n vault port-forward svc/vault 8200:8200 &
curl -v localhost:8200

curl --request POST \
 --data '{"jwt": "'$TOKEN_REVIEW_SJWT'", "role": "k8s"}' \
   http://localhost:8200/v1/auth/kubernetes/login

#################################################################################
# 4) add demo app into arogocd with vault
#################################################################################
argocd app list
#argocd app delete devops-demo
#argocd app create devops-demo \
#  --project devops \
#  --repo https://github.com/tzkr/tz-argocd-repo.git \
#  --path devops-demo/dev \
#  --dest-namespace devops \
#  --dest-server https://kubernetes.default.svc --directory-recurse --upsert --grpc-web

vault kv put secret/devops-prod/dbinfo name=123 passwod=456 ttl=789
vault kv get secret/devops-prod/dbinfo

kubectl delete -f demo/demo-application.yaml
kubectl apply -f demo/demo-application.yaml
kubectl apply -f demo/svcaccount.yaml

kubectl delete -f demo/demo-application-dev.yaml
kubectl apply -f demo/demo-application-dev.yaml

argocd app sync devops-demo
argocd app sync devops-demo-demo

#################################################################################
# 5) apply vault's change into app
#################################################################################
vault kv put secret/devops-prod/dbinfo name=a123 passwod=a456 ttl=a789
vault kv get secret/devops-prod/dbinfo

argocd app get argocd/devops-demo --hard-refresh
kubectl get secret devops-demo-argocd-vault-credentials-argo-vault -o yaml -n devops
echo 'MTIz' | base64 -d
kubectl rollout restart deployment devops-demo-argo-vault -n devops

curl https://argo-vault.devops.eks-main-t.tzcorp.com/index

exit 0

# Installing locally
#On Linux or macOS via Curl
curl -Lo argocd-vault-plugin https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v1.13.1/argocd-vault-plugin_1.13.1_linux_arm64
chmod +x argocd-vault-plugin
mv argocd-vault-plugin /usr/local/bin
#On macOS via Homebrew
brew install argocd-vault-plugin

sh -c "find . -name '*.yaml' -exec grep -l \"<path\\|avp\\.kubernetes\\.io/path\" {} \;"
sh -c "find . -name '*.yaml' | xargs -I {} grep \"<path\\|avp\\.kubernetes\\.io/path\" {} | grep ."
- "find . -name 'secret.yaml'"