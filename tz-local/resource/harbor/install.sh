#!/usr/bin/env bash

#https://kubesphere.io/docs/devops-user-guide/how-to-integrate/harbor/

#bash /vagrant/tz-local/resource/harbor/install.sh
cd /vagrant/tz-local/resource/harbor

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

function prop {
  if [[ "${3}" == "" ]]; then
    grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
  else
    grep "${3}" "/home/vagrant/.aws/${1}" -A 10 | grep "${2}" | head -n 1 | tail -n 1 | cut -d '=' -f2 | sed 's/ //g'
  fi
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
basic_password=$(prop 'project' 'basic_password')
NS=default

helm repo add harbor https://helm.goharbor.io
helm uninstall harbor-release
cp -Rf values.yaml values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" values.yaml_bak
sed -i "s|NS|devops|g" values.yaml_bak
helm upgrade --debug --install --reuse-values harbor-release harbor/harbor -f values.yaml

kubectl patch deploy/kube-state-metrics -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-monitoring-system
kubectl patch statefulSet/alertmanager-main -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-monitoring-system

sleep 30

cp -Rf harbor-ingress.yaml harbor-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" harbor-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" harbor-ingress.yaml_bak
sed -i "s|NS|devops|g" harbor-ingress.yaml_bak
k delete -f harbor-ingress.yaml_bak
k apply -f harbor-ingress.yaml_bak

echo https://harbor.default.${eks_project}.${eks_domain}
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
#  "insecure-registries":["harbor.default.eks-main.tzcorp.com"]
#}
#systemctl restart docker
#
#docker login harbor.default.eks-main.tzcorp.com
#admin / ${admin_password}

