#!/usr/bin/env bash

#https://learn.hashicorp.com/tutorials/consul/kubernetes-secure-agents
#https://stackoverflow.com/questions/62023421/hashicorp-consul-how-to-do-verified-tls-from-pods-in-kubernetes-cluster
#https://discuss.hashicorp.com/t/consul-verified-tls-from-pods-in-kubernetes-cluster/9208/11

cd /vagrant/tz-local/resource/consul/ca

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
#Create CA
##################################################
# https://www.consul.io/docs/k8s/helm
rm -Rf *.cert *.pem *.crt *.csr *.key *.srl
#consul tls ca create -domain=consul
#
#k delete secret consul-ca-key
#k delete secret consul-ca-cert
#
#k create secret generic consul-ca-cert \
#    --from-file='tls.crt=./consul-agent-ca.pem'
#k create secret generic consul-ca-key \
#    --from-file='tls.key=./consul-agent-ca-key.pem'

k get secret consul-server-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > /vagrant/resources/consul-agent-ca.pem
k get secret consul-server-cert -o jsonpath="{.data['tls\.key']}" | base64 --decode > /vagrant/resources/consul-agent-ca-key.pem
export CONSUL_CLIENT_CERT=/vagrant/resources/consul-agent-ca.pem
export CONSUL_CLIENT_KEY=/vagrant/resources/consul-agent-ca-key.pem

k get secret consul-ca-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > /vagrant/resources/${eks_project}_consul-ca.pem
export CONSUL_CACERT=/vagrant/resources/${eks_project}_consul-ca.pem

#cp -Rf consul-agent-ca.pem /vagrant/resources/${eks_project}_consul-ca.pem

##################################################
#Create server certificate
##################################################
consul tls cert create -server -days=730 -domain=consul -ca=consul-agent-ca.pem \
    -key=consul-agent-ca-key.pem -dc=tz-dc \
    -additional-dnsname="consul.service.consul" \
    -additional-dnsname="consul-dns.svc.cluster.local" \
    -additional-dnsname="consul-server.consul.svc.cluster.local" \
    -additional-dnsname="consul-server" \
    -additional-dnsname="*.ingress.local" \
    -additional-dnsname="*.consul-server" \
    -additional-dnsname="*.consul-server.consul" \
    -additional-dnsname="*.consul-server.consul.svc" \
    -additional-dnsname="*.server.tz-dc.tzcorp.com" \
    -additional-dnsname="server.tz-dc.tzcorp.com"

openssl req -new -newkey rsa:2048 -nodes -keyout server.tz-dc.consul.key -out server.tz-dc.consul.csr -subj '/CN=server.tz-dc.consul' -config <(
cat <<-EOF
[req]
req_extensions = req_ext
distinguished_name = dn
[ dn ]
CN = *.tz-dc.consul
[ req_ext ]
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = server.tz-dc.consul
DNS.2 = localhost
DNS.3 = consul.service.consul
DNS.4 = consul-server.consul.svc.cluster.local
IP.1  = 127.0.0.1
EOF
)
#ls -al server.tz-dc.consul*

#Step 2: sign the CSR
openssl x509 -req -in server.tz-dc.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -CAcreateserial -out server.tz-dc.consul.crt
openssl x509 -text -noout -in server.tz-dc.consul.crt

k delete secret consul-server-cert
k create secret generic consul-server-cert \
    --from-file='tls.crt=tz-dc-server-consul-0.pem' \
    --from-file='tls.key=tz-dc-server-consul-0-key.pem'

helm upgrade --debug --install --reuse-values consul hashicorp/consul -f vaules.yaml -n consul --version 0.32.1
k patch job/consul-server-acl-init -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "consul"}}}}}'

##################################################
#Create clients certificate
##################################################
#Create a certificate for clients:
consul tls cert create -client -dc=tz-dc

#Create the CSR:
openssl req -new -newkey rsa:2048 -nodes -keyout client.tz-dc.consul.key -out client.tz-dc.consul.csr -subj '/CN=client.tz-dc.consul' -config <(
cat <<-EOF
[req]
req_extensions = req_ext
distinguished_name = dn
[ dn ]
CN = *.tz-dc.consul
[ req_ext ]
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = server.tz-dc.consul
DNS.2 = localhost
DNS.3 = consul.service.consul
DNS.4 = consul-server.consul.svc.cluster.local
IP.1  = 127.0.0.1
EOF
)
#Sign the certificate:
openssl x509 -req -in client.tz-dc.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -out client.tz-dc.consul.crt

##################################################
#Create a certificate for cli:
##################################################
consul tls cert create -cli -days=730 -domain=consul -ca=consul-agent-ca.pem \
    -key=consul-agent-ca-key.pem -dc=tz-dc \
    -additional-dnsname="consul-dns.svc.cluster.local" \
    -additional-dnsname="consul-server.consul.svc.cluster.local" \
    -additional-dnsname="consul-server" \
    -additional-dnsname="*.ingress.local" \
    -additional-dnsname="*.consul-server" \
    -additional-dnsname="*.consul-server.consul" \
    -additional-dnsname="*.consul-server.consul.svc" \
    -additional-dnsname="*.server.tz-dc.tzcorp.com" \
    -additional-dnsname="server.tz-dc.tzcorp.com"

#Step 1: create server certificate signing requests
openssl req -new -newkey rsa:2048 -nodes -keyout cli.client.tz-dc.consul.key -out cli.client.tz-dc.consul.csr -subj '/CN=cli.client.tz-dc.consul' -config <(
cat <<-EOF
[req]
req_extensions = req_ext
distinguished_name = dn
[ dn ]
CN = *.tz-dc.consul
[ req_ext ]
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = server.tz-dc.consul
DNS.2 = localhost
DNS.3 = consul-server.consul.svc.cluster.local
IP.1  = 127.0.0.1
EOF
)
#ls -al cli.client.tz-dc.consul*
#Step 2: sign the CSR
openssl x509 -req -in cli.client.tz-dc.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -CAcreateserial -out cli.client.tz-dc.consul.crt
openssl x509 -text -noout -in cli.client.tz-dc.consul.crt
#Sign the certificate:
openssl x509 -req -in cli.client.tz-dc.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -out cli.client.tz-dc.consul.crt

cp -Rf tz-dc-cli-consul-0.pem /vagrant/resources
cp -Rf tz-dc-cli-consul-0-key.pem /vagrant/resources

#k port-forward consul-server-0 8501:8501 &
#export CONSUL_HTTP_ADDR=consul-server.default.${eks_project}.tzcorp.com
export CONSUL_CACERT=/vagrant/resources/${eks_project}_consul-ca.pem
export CONSUL_CLIENT_CERT=/vagrant/resources/tz-dc-cli-consul-0.pem
export CONSUL_CLIENT_KEY=/vagrant/resources/tz-dc-cli-consul-0-key.pem
export CONSUL_HTTP_ADDR=https://127.0.0.1:8501
consul members

#consul members -http-addr="https://consul.default.${eks_project}.tzcorp.com"
rm -Rf *.cert *.pem *.crt *.csr *.key *.srl

consul members
consul acl policy list
consul acl token list
CONSUL_TOKEN=$(consul acl token list | grep -B 6 global-management | head -n 1 | cut -d ':' -f2 | sed 's/ //g')
CONSUL_SECRET=$(consul acl token read -id ${CONSUL_TOKEN} | grep SecretID | cut -d ':' -f2 | sed 's/ //g')
echo "CONSUL_TOKEN: ${CONSUL_TOKEN}"
echo "CONSUL_SECRET: ${CONSUL_SECRET}"

#/ # consul acl bootstrap
#AccessorID:       239ff2d7-008b-77c2-f8b3-935e0126c432
#SecretID:         ddf5a531-a59f-4e77-9f48-f8013badafce
#Description:      Bootstrap Token (Global Management)
#Local:            false
#Create Time:      2021-08-31 02:59:43.950300581 +0000 UTC
#Policies:
#   00000000-0000-0000-0000-000000000001 - global-management
#
consul members -token ${CONSUL_SECRET}
#consul members -token ce25769a-1f07-dd44-4a80-1814d12c0538

cp -Rf consul-ingress.yaml consul-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" consul-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" consul-ingress.yaml_bak
k delete -f consul-ingress.yaml_bak
k apply -f consul-ingress.yaml_bak

#export CONSUL_CACERT=/vagrant/resources/${eks_project}_consul-ca.pem
#export CONSUL_CLIENT_CERT=/vagrant/resources/tz-dc-cli-consul-0.pem
#export CONSUL_CLIENT_KEY=/vagrant/resources/tz-dc-cli-consul-0-key.pem

#kubectl get configmap coredns -n kube-system -o yaml > core-dns.yaml

export CONSUL_DNS_IP=$(k get svc consul-dns -o jsonpath='{.spec.clusterIP}')
echo "CONSUL_DNS_IP: ${CONSUL_DNS_IP}"

cp -Rf core-dns.yaml core-dns.yaml_bak
sed -i "s/CONSUL_DNS_IP/${CONSUL_DNS_IP}/g" core-dns.yaml_bak
kubectl -n kube-system apply -f core-dns.yaml_bak
kubectl -n kube-system rollout restart deploy/coredns

kubectl -n consul run -it busybox --image=alpine:3.6 --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "consul" } } }' -- sh
#apk update && apk add bind-tools
dig consul-server.consul.svc.cluster.local
dig consul-dns.consul.svc.cluster.local
dig consul.svc.cluster.local svc.cluster.local cluster.local ap-northeast-2.compute.internal
dig consul-server-0.consul-server.consul.svc

exit 0




