#!/usr/bin/env bash

#https://learn.hashicorp.com/tutorials/consul/kubernetes-secure-agents

#https://www.consul.io/docs/k8s/connect/connect-ca-provider
# https://learn.hashicorp.com/tutorials/consul/kubernetes-secure-agents
# https://learn.hashicorp.com/tutorials/consul/access-control-setup-production#create-the-initial-bootstrap-token

#https://www.linkedin.com/pulse/using-consul-auto-encrypt-k8s-issac-goldstand/
#https://githubmemory.com/repo/hashicorp/consul-helm/issues

#bash /vagrant/tz-local/resource/consul/secured/install.sh
cd /vagrant/tz-local/resource/consul/secured

#set -x
shopt -s expand_aliases
alias k='kubectl -n consul'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
consul_token=$(prop 'project' 'consul-token')

##################################################
# Install an unsecured Consul service
##################################################
#bash ../install.sh
#k exec $(k get pods -l component=client -o jsonpath='{.items[0].metadata.name}') -- consul catalog services

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul

kubectl label namespaces consul "consul.hashicorp.com/transparent-proxy=true"
kubectl label namespaces devops-dev "consul.hashicorp.com/transparent-proxy=true"

k delete secret consul-gossip-encryption-key
k create secret generic consul-gossip-encryption-key --from-literal=key=$(consul keygen)
cp vaules.yaml vaules.yaml_bak
helm upgrade --debug --install --reuse-values consul hashicorp/consul -f vaules.yaml_bak -n consul --version 0.32.1

k patch deployment/consul-controller -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "consul"}}}}}'
k patch deployment/consul-connect-injector-webhook-deployment -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "consul"}}}}}'

export CONSUL_HTTP_ADDR=consul-server.${NS}.${eks_project}.${eks_domain}
export CONSUL_HTTP_TOKEN=$(k get secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)
echo "CONSUL_HTTP_TOKEN: ${CONSUL_HTTP_TOKEN}"
if [[ "${CONSUL_HTTP_TOKEN}" != "" ]]; then
  sed -i "s/${consul_token}/${CONSUL_HTTP_TOKEN}/g" /vagrant/resources/project
  sed -i "s/${consul_token}/${CONSUL_HTTP_TOKEN}/g" /home/vagrant/.aws/project
fi

k get secret consul-server-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > /vagrant/resources/consul-agent-ca.pem
k get secret consul-server-cert -o jsonpath="{.data['tls\.key']}" | base64 --decode > /vagrant/resources/consul-agent-ca-key.pem
export CONSUL_CLIENT_CERT=/vagrant/resources/consul-agent-ca.pem
export CONSUL_CLIENT_KEY=/vagrant/resources/consul-agent-ca-key.pem

k get secret consul-ca-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > /vagrant/resources/${eks_project}_consul-ca.pem
export CONSUL_CACERT=/vagrant/resources/${eks_project}_consul-ca.pem

#consul members -ca-file /vagrant/resources/${eks_project}_consul-ca.pem
consul members

#k port-forward consul-server-0 8501:8501 &
#export CONSUL_HTTP_ADDR=https://127.0.0.1:8501
#consul debug -ca-file /vagrant/resources/${eks_project}_consul-ca.pem

k delete -f server.yaml
k delete -f client.yaml
k apply -f server.yaml
k apply -f client.yaml

k exec deploy/static-client -c static-client -- curl -s http://static-server
k exec deploy/static-client -c static-client -- curl -s http://static-server.consul.svc.cluster.local
k delete -f client-to-server-intention.yaml
k apply -f client-to-server-intention.yaml
k exec deploy/static-client -c static-client -- curl -s http://static-server
k delete -f client-to-server-intention.yaml

consul config list -kind service-defaults

exit 0

