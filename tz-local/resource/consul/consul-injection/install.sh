#!/usr/bin/env bash

# https://github.com/joatmon08/consul-k8s-ingress-controllers

#bash /vagrant/tz-local/resource/consul/consul-injection/install.sh
cd /vagrant/tz-local/resource/consul/consul-injection

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')

kubectl delete -f consul-demo.yaml -n consul --grace-period=0 --force
kubectl apply -f consul-demo.yaml -n consul
#curl http://consul-agent-demo.consul.svc.cluster.local

cp -Rf consul-ingress.yaml consul-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" consul-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" consul-ingress.yaml_bak
sed -i "s|NS|${NS}|g" consul-ingress.yaml_bak
k apply -f consul-ingress.yaml_bak

vault policy write tz-consul-devops-dev /vagrant/tz-local/resource/vault/data/devops-dev.hcl
vault write auth/kubernetes/role/consul-agent-demo2-role \
        bound_service_account_names=consul-agent-demo2-account \
        bound_service_account_namespaces=consul \
        policies=tz-vault-devops-dev \
        ttl=24h

kubectl delete -f consul-demo2.yaml -n consul --grace-period=0 --force
kubectl apply -f consul-demo2.yaml -n consul


kubectl -n consul port-forward svc/consul-agent-demo 8080:8080
curl -v localhost:8080

cp -Rf service.yaml service.yaml_bak
sed -i "s/eks_project/${eks_project}/g" service.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" service.yaml_bak
sed -i "s|NS|${NS}|g" service.yaml_bak
kubectl -n consul apply -f service.yaml
kubectl -n consul apply -f service-router.yaml

kubectl -n consul exec -it deploy/static-client -- curl -s http://consul-agent-demo:8080
kubectl -n consul exec -it deploy/static-client -- sh
  curl http://consul-agent-demo.consul.svc.cluster.local

curl -v http://demo.${NS}.${eks_project}.${eks_domain}/confees

kubectl -n consul get ServiceRouter
kubectl -n consul delete ServiceRouter product-api-service

kubectl -n consul apply -f consul-demo2.yaml
#  http://localhost:9090/coffees

kubectl -n consul apply -f deploy-service/service-resolver.yaml
kubectl get ServiceResolver -n consul
kubectl -n consul apply -f deploy-service/service-splitter.yaml



kubectl -n consul exec -it deploy/consul-agent-demo -- sh
curl http://consul-agent-demo2:8080

curl http://consul-agent-demo2:8080
curl http://consul-agent-demo2.consul.svc.cluster.local:8080



exit 0

cp -Rf static-ingress.yaml static-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" static-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" static-ingress.yaml_bak
sed -i "s|NS|${NS}|g" static-ingress.yaml_bak

kubectl -n consul delete -f static-server.yaml
kubectl -n consul delete -f static-client.yaml
kubectl -n consul delete -f static-intention.yaml
kubectl -n consul delete -f static-ingress.yaml_bak
kubectl -n consul delete -f static-gateway.yaml
kubectl -n consul delete -f static-router.yaml

kubectl -n consul apply -f static-server.yaml
kubectl -n consul apply -f static-client.yaml
kubectl -n consul apply -f static-ingress.yaml_bak

kubectl -n consul apply -f static-intention.yaml
kubectl -n consul apply -f static-gateway.yaml
kubectl -n consul apply -f static-router.yaml

export CONSUL_HTTP_ADDR=consul-server.${NS}.${eks_project}.${eks_domain}
export CONSUL_HTTP_TOKEN=$(k get secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)
echo "CONSUL_HTTP_ADDR: ${CONSUL_HTTP_ADDR}"
echo "CONSUL_HTTP_TOKEN: ${CONSUL_HTTP_TOKEN}"

consul members -ca-file /vagrant/resources/${eks_project}_consul-ca.pem
consul intention create -deny "*" "*"
consul config write default-web.hcl
#consul intention create -allow "*" "*"

#apk update && apk add bind-tools && apk add curl
#kubectl -n consul exec -it static-client-6ff7954bb4-m89lw -- sh
#cat /etc/resolv.conf
#nameserver 172.20.0.10
#search consul.svc.cluster.local svc.cluster.local cluster.local ap-northeast-2.compute.internal
#options ndots:5

kubectl -n consul exec deploy/static-client -- curl -s http://static-server/
kubectl -n consul apply -f ingress-gateway.yaml

#nslookup consul-server.svc.cluster.local
#Server:         172.20.0.10
#Address:        172.20.0.10:53
#nc -zv consul-server.consul.svc.cluster.local 53
#consul-server.consul.svc.cluster.local (10.20.108.182:53) open

nc -zv static-server 80

k patch job/consul-server-acl-init -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "consul"}}}}}'












