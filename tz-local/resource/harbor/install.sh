#!/usr/bin/env bash

#https://kubesphere.io/docs/devops-user-guide/how-to-integrate/harbor/

source /root/.bashrc
#bash /vagrant/tz-local/resource/harbor/install.sh
cd /vagrant/tz-local/resource/harbor

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
basic_password=$(prop 'project' 'basic_password')
NS=default

helm repo add harbor https://helm.goharbor.io
helm uninstall harbor-release
#helm show values harbor/harbor > values.yaml
cp -Rf values.yaml values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" values.yaml_bak
sed -i "s|NS|devops|g" values.yaml_bak
#--reuse-values
helm upgrade --debug --install --reuse-values harbor-release harbor/harbor -f values.yaml_bak

sleep 30

#cp -Rf harbor-ingress.yaml harbor-ingress.yaml_bak
#sed -i "s/eks_project/${eks_project}/g" harbor-ingress.yaml_bak
#sed -i "s/eks_domain/${eks_domain}/g" harbor-ingress.yaml_bak
#sed -i "s|NS|devops|g" harbor-ingress.yaml_bak
#k delete -f harbor-ingress.yaml_bak
#k apply -f harbor-ingress.yaml_bak

echo https://harbor.devops.${eks_project}.${eks_domain}
echo admin / Harbor12345

#new project: ks-devops-harbor
#NEW ROBOT ACCOUNT in Robot Accounts.
#robot account: robot-test

#      tolerations: []
#    enabled: false
#  local_registry: '172.20.247.60:80'  # Add a new field of Harbor address to this line.
#  logging:
#    enabled: false

#vi /etc/docker/daemon.json
#{
#  "insecure-registries":["harbor.devops.eks-main-t.shoptoolstest.co.kr"]
#}
#systemctl restart docker
#
#docker login harbor.devops.eks-main-t.shoptoolstest.co.kr
#admin / ${admin_password}

