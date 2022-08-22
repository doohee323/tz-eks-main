#!/usr/bin/env bash

# https://learn.hashicorp.com/tutorials/consul/service-mesh-deploy?in=consul/gs-consul-service-mesh
#https://www.youtube.com/watch?v=_jTnlXgYUyg

#bash /vagrant/tz-local/resource/consul/mesh/install.sh
cd /vagrant/tz-local/resource/consul/mesh

#set -x
shopt -s expand_aliases
alias k='kubectl -n consul'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
basic_password=$(prop 'project' 'basic_password')

k apply -f upgrade.yaml

k exec consul-server-0 -- consul config read -name tz-consul-service -kind service-defaults
k get ServiceDefaults tz-consul-service -o yaml
k describe servicedefaults tz-consul-service

k get pods --selector app=consul
k exec -it consul-server-0 -- consul members
k get pods --selector consul.hashicorp.com/connect-inject-status=injected

k delete -f hashicups
k apply -f hashicups
#k apply -f hashicups/public-api.yaml
#kubectl -n delete apply -f hashicups/public-api.yaml

k port-forward svc/public-api 8080:8080
k port-forward svc/frontend 8081:80
k port-forward svc/product-api 9090:9090
#  http://localhost:9090/coffees
k apply -f service-to-service.yaml

k apply -f deploy-service/service.yaml
k apply -f deploy-service/v1
k apply -f deploy-service/service-router.yaml
k port-forward svc/product-api 9090:9090
#  http://localhost:9090/coffees
k apply -f deploy-service/v2
k port-forward svc/product-api 9091:9090
#  http://localhost:9090/coffees

k apply -f deploy-service/service-resolver.yaml
kubectl get ServiceResolver -n consul
k apply -f deploy-service/service-splitter.yaml

exit 0

kubectl run -it busybox --image=alpine:3.6 -n consul --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "consul" } } }' -- sh
k exec -it busybox -- sh


kubectl port-forward --address 0.0.0.0 consul-server-0 8501:8501
export CONSUL_HTTP_ADDR=https://127.0.0.1:8501
k get secret consul-ca-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > ca.pem
consul members -ca-file ca.pem
