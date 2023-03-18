#!/usr/bin/env bash

source /root/.bashrc
cd /vagrant/tz-local/resource/consul

#set -x
shopt -s expand_aliases
alias k='kubectl -n consul'

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
basic_password=$(prop 'project' 'basic_password')
NS=consul

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul

helm uninstall consul -n consul
k delete PersistentVolumeClaim data-consul-consul-server-0
kubectl delete namespace consul

k create namespace consul
cp values.yaml values.yaml_bak
helm upgrade --debug --install --reuse-values consul hashicorp/consul -f /vagrant/tz-local/resource/consul/values.yaml_bak -n consul --version 1.0.2

cp -Rf consul-ingress.yaml consul-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" consul-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" consul-ingress.yaml_bak
sed -i "s|NS|${NS}|g" consul-ingress.yaml_bak
k delete -f consul-ingress.yaml_bak -n consul
k apply -f consul-ingress.yaml_bak -n consul

#kubectl get certificate -n consul
#kubectl describe certificate ingress-consul-tls -n consul

#kubectl -n consul apply -f mesh/upgrade.yaml

#k delete -f /vagrant/tz-local/resource/consul/consul.yaml -n consul
#k apply -f /vagrant/tz-local/resource/consul/consul.yaml -n consul
#k get pod/tz-consul-deployment-78597cd9c5-vsbg4 -o yaml > a.yaml

#k create -f /vagrant/tz-local/resource/consul/counting.yaml -n consul
#k create -f /vagrant/tz-local/resource/consul/dashboard.yaml -n consul

sleep 60

export CONSUL_HTTP_ADDR="consul.default.${eks_project}.${eks_domain}"
echo http://$CONSUL_HTTP_ADDR
consul members

exit 0

