#!/usr/bin/env bash

source /root/.bashrc
cd /vagrant/tz-local/resource/argocd

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

k delete namespace argocd
k create namespace argocd
k delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
k apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 20
k patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 120
TMP_PASSWORD=$(k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "############################################"
echo "TMP_PASSWORD: ${TMP_PASSWORD}"
echo "############################################"

VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd

argocd login `k get service -n argocd | grep -w "argocd-server " | awk '{print $4}'` --username admin --password ${TMP_PASSWORD} --insecure
argocd account update-password --account admin --current-password ${TMP_PASSWORD} --new-password ${admin_password}

cp -Rf ingress-argocd.yaml ingress-argocd.yaml_bak
sed -i "s/eks_project/${eks_project}/g" ingress-argocd.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" ingress-argocd.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" ingress-argocd.yaml_bak
k delete -f ingress-argocd.yaml_bak -n argocd
k apply -f ingress-argocd.yaml_bak -n argocd

argocd login `k get service -n argocd | grep argocd-server | awk '{print $4}' | head -n 1` --username admin --password ${admin_password} --insecure
argocd repo add https://github.com/doohee323/tz-argocd-repo \
  --username doohee323 --password ${github_token}

bash /vagrant/tz-local/resource/argocd/update.sh
bash /vagrant/tz-local/resource/argocd/update.sh

exit 0
