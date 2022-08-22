#!/usr/bin/env bash

#https://coffeewhale.com/kubernetes/gitops/helm/2020/05/13/helm-operator/

#bash /vagrant/tz-local/resource/helm-operator/install.sh
cd /vagrant/tz-local/resource/helm-operator

#set -x
shopt -s expand_aliases

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')

alias k='kubectl --kubeconfig ~/.kube/config'
#alias k="kubectl --kubeconfig ~/.kube/kubeconfig_${eks_project}"

kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml
kubectl create ns flux
helm repo add fluxcd https://charts.fluxcd.io
helm upgrade -i helm-operator fluxcd/helm-operator \
    --namespace flux \
    --set helm.versions=v3 \
    --set initPlugins.enable=true \
    --set 'initPlugins.plugins[0].plugin=https://github.com/hypnoglow/helm-s3.git' \
    --set 'initPlugins.plugins[0].version=0.9.2' \
    --set 'initPlugins.plugins[0].helmVersion=v3'

export AWS_REGION="ap-northeast-2"
AWS_REGION=ap-northeast-2 kubectl apply -f devops-demo-dev.yaml
kubectl apply -f devops-demo-dev.yaml

helm repo remove devops-demo-helm-repo
#AWS_REGION=ap-northeast-2 helm repo add devops-demo-helm-repo s3://tz-helm-devops-demo-helm-bucket/charts
helm repo add devops-demo-helm-repo https://tzkr.github.io/tz-helm-charts/ --force-update
helm repo update
helm search repo devops-demo-helm-repo
echo sudo helm uninstall devops-demo-helm -n devops-dev
sudo helm uninstall devops-demo-helm -n devops-dev
echo sudo helm install devops-demo-helm devops-demo-helm-repo/devops-demo-helm -n devops-dev
sudo helm install devops-demo-helm devops-demo-helm-repo/devops-demo-helm -n devops-dev

exit 0



