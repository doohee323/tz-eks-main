#!/usr/bin/env bash

# https://github.com/aws-quickstart/quickstart-eks-hashicorp-consul

#bash /vagrant/tz-local/resource/consul/install.sh
cd /vagrant/tz-local/resource/consul

#set -x
shopt -s expand_aliases
alias k='kubectl -n consul'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
basic_password=$(prop 'project' 'basic_password')
NS=consul

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul

helm uninstall consul -n consul
k delete PersistentVolumeClaim data-consul-consul-server-0
kubectl delete namespace consul
#kubectl proxy
#kubectl get ns consul -o json | \
#  jq '.spec.finalizers=[]' | \
#  curl -X PUT http://localhost:8001/api/v1/namespaces/consul/finalize -H "Content-Type: application/json" --data @-

k create namespace consul
cp values.yaml values.yaml_bak
helm upgrade --debug --install --reuse-values consul hashicorp/consul -f /vagrant/tz-local/resource/consul/values.yaml_bak -n consul --version 0.37.0
#kubectl rollout restart statefulset.apps/consul-server -n consul
#helm install consul hashicorp/consul --set global.name=consul
#k taint nodes --all node-role.kubernetes.io/master-

# basic auth
#https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
#https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
#echo ${basic_password} | htpasswd -i -n admin > auth
#k create secret generic basic-auth-consul --from-file=auth -n consul
#k get secret basic-auth-consul -o yaml -n consul
#rm -Rf auth

# to NodePort
#k patch svc consul-ui --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":31699}]' -n consul
#k port-forward service/consul-server 8500:8500 -n consul &
cp -Rf consul-ingress.yaml consul-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" consul-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" consul-ingress.yaml_bak
sed -i "s|NS|${NS}|g" consul-ingress.yaml_bak
k delete -f consul-ingress.yaml_bak -n consul
k apply -f consul-ingress.yaml_bak -n consul

#kubectl get certificate -n consul
#kubectl describe certificate ingress-consul-tls -n consul

k patch statefulset/consul-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n consul
k patch statefulset/consul-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "consul"}}}}}' -n consul
k patch statefulset/consul-server -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n consul

k patch daemonset/consul -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n consul
k patch deployment/consul-connect-injector-webhook-deployment -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n consul
k patch deployment/consul-controller -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n consul
k patch deployment/consul-sync-catalog -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n consul
k patch deployment/consul-webhook-cert-manager -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n consul

#kubectl -n consul apply -f mesh/upgrade.yaml

#k delete -f /vagrant/tz-local/resource/consul/consul.yaml -n consul
#k apply -f /vagrant/tz-local/resource/consul/consul.yaml -n consul
#k get pod/tz-consul-deployment-78597cd9c5-vsbg4 -o yaml > a.yaml

#k create -f /vagrant/tz-local/resource/consul/counting.yaml -n consul
#k create -f /vagrant/tz-local/resource/consul/dashboard.yaml -n consul

sleep 60

#curl http://consul.${eks_project}.${eks_domain}/

# install for test on host
#wget https://releases.hashicorp.com/consul/1.8.4/consul_1.8.4_linux_amd64.zip
#unzip consul_1.8.4_linux_amd64.zip
#rm -Rf consul_1.8.4_linux_amd64.zip
#chmod +x consul
#sudo mv consul /usr/local/bin/

export CONSUL_HTTP_ADDR="consul.default.${eks_project}.${eks_domain}"
#export CONSUL_HTTP_ADDR="127.0.0.1:8500"
echo http://$CONSUL_HTTP_ADDR
consul members
curl http://consul.default.${eks_project}.${eks_domain}/v1/status/leader

echo '
##[ Consul ]##########################################################
- url: http://consul.default.eks_project.eks_domain

consul kv put hello world
consul kv get hello
consul kv put redis/config/connections 5
consul kv get redis/config/connections
consul kv get -recurse redis/config

consul watch -type=key -key=redis/config/connections ./my-key-handler.sh
#consul watch -type=keyprefix -prefix=redis/config/ ./my-key-handler.sh
vi my-key-handler.sh
#!/bin/bash
while read line
do
    echo $line >> dump.txt
done

consul kv put redis/config/connections 5
vi dump.txt
{"Key":"redis/config/connections","CreateIndex":510,"ModifyIndex":510,"LockIndex":0,"Flags":0,"Value":"NQ==","Session":""}
echo "NQ==" | base64 --decode

consul watch -type=event -name=web-deploy ./my-key-handler.sh -web-deploy
consul event -name=web-deploy 1609030
[{"ID":"b3abd566-f0c9-ce2d-1359-b855fd9050eb","Name":"web-deploy","Payload":"MTYwOTAzMA==","NodeFilter":"","ServiceFilter":"","TagFilter":"","Version":1,"LTime":3}]
echo "MTYwOTAzMA==" | base64 --decode

consul snapshot save tz-consul.snap
ls tz-consul.snap
consul snapshot inspect tz-consul.snap

#######################################################################
' >> /vagrant/info
sed -i "s/eks_project/${eks_project}/g" /vagrant/info
sed -i "s/eks_domain/${eks_domain}/g" /vagrant/info
cat /vagrant/info

exit 0


apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: consul
  namespace: consul
~~~~~
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: beta.kubernetes.io/instance-type
                operator: NotIn
                values:
                - t3.small



consul kv import @vault.json
cat vault.json | consul kv import -
consul kv import "$(cat vault.json)"
cat vault.json | consul kv import -prefix=sub/dir/ -
