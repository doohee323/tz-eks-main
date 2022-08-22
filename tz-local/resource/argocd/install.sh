#!/usr/bin/env bash

#https://faun.pub/create-argo-cd-local-users-9e830db3763f
#https://medium.com/finda-tech/eks-cluster%EC%97%90-argo-cd-%EB%B0%B0%ED%8F%AC-%EB%B0%8F-%EC%84%B8%ED%8C%85%ED%95%98%EB%8A%94-%EB%B2%95-eec3bef7b69b

#bash /vagrant/tz-local/resource/argocd/install.sh
cd /vagrant/tz-local/resource/argocd

#set -x
shopt -s expand_aliases

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
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

k patch deploy/argocd-redis -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n argocd

argocd login `k get service -n argocd | grep argocd-server | awk '{print $4}' | head -n 1` --username admin --password ${admin_password} --insecure
argocd repo add https://github.com/tzkr/tz-helm-charts \
  --username devops-tz --password ${github_token}

bash /vagrant/tz-local/resource/argocd/update.sh
bash /vagrant/tz-local/resource/argocd/update.sh

exit 0


