#!/usr/bin/env bash

# https://learn.hashicorp.com/tutorials/consul/tls-encryption-openssl-secure
# https://learn.hashicorp.com/tutorials/consul/tls-encryption-openssl-secure#create-certificates

######################################################################
#I. Create certificates
######################################################################
######################################################################
#II. Configure agents
######################################################################
######################################################################
#III. Configure the Consul CLI for HTTPS
######################################################################
######################################################################
#VI. Configure the Consul UI for HTTPS
######################################################################


#set -x
shopt -s expand_aliases
alias k='kubectl -n consul'

######################################################################
#I. Create certificates
######################################################################

#Initialize the built-in CA
consul tls ca create
#==> Saved consul-agent-ca.pem
#==> Saved consul-agent-ca-key.pem

########################################################################
#Create the server certificates
consul tls cert create -server
#Step 1: create server certificate signing requests
#openssl req -new -newkey rsa:2048 -nodes -keyout server1.dc1.consul.key -out server1.dc1.consul.csr -subj '/CN=server1.dc1.consul'
openssl req -new -newkey rsa:2048 -nodes -keyout server1.dc1.consul.key -out server1.dc1.consul.csr -subj '/CN=server1.dc1.consul' -config <(
cat <<-EOF
[req]
req_extensions = req_ext
distinguished_name = dn
[ dn ]
CN = *.dc1.consul
[ req_ext ]
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = server1.dc1.consul
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF
)
#ls -al server1.dc1.consul*

#Step 2: sign the CSR
openssl x509 -req -in server1.dc1.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -CAcreateserial -out server1.dc1.consul.crt
#ls -1
openssl x509 -text -noout -in server1.dc1.consul.crt
########################################################################

########################################################################
#Create a certificate for clients:
consul tls cert create -client

#Create clients certificate
#Create the CSR:
openssl req -new -newkey rsa:2048 -nodes -keyout client.dc1.consul.key -out client.dc1.consul.csr -subj '/CN=client.dc1.consul' -config <(
cat <<-EOF
[req]
req_extensions = req_ext
distinguished_name = dn
[ dn ]
CN = *.dc1.consul
[ req_ext ]
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = server1.dc1.consul
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF
)
#Sign the certificate:
openssl x509 -req -in client.dc1.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -out client.dc1.consul.crt
########################################################################

########################################################################
#Create a certificate for cli:
consul tls cert create -cli

#Step 1: create server certificate signing requests
#openssl req -new -newkey rsa:2048 -nodes -keyout cli.client.dc1.consul.key -out cli.client.dc1.consul.csr -subj '/CN=cli.client.dc1.consul'
openssl req -new -newkey rsa:2048 -nodes -keyout cli.client.dc1.consul.key -out cli.client.dc1.consul.csr -subj '/CN=cli.client.dc1.consul' -config <(
cat <<-EOF
[req]
req_extensions = req_ext
distinguished_name = dn
[ dn ]
CN = *.dc1.consul
[ req_ext ]
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = server1.dc1.consul
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF
)
#ls -al cli.client.dc1.consul*

#Step 2: sign the CSR
openssl x509 -req -in cli.client.dc1.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -CAcreateserial -out cli.client.dc1.consul.crt
#ls -1
openssl x509 -text -noout -in cli.client.dc1.consul.crt

#Sign the certificate:
openssl x509 -req -in cli.client.dc1.consul.csr -CA consul-agent-ca.pem -CAkey consul-agent-ca-key.pem -out cli.client.dc1.consul.crt
########################################################################


######################################################################
#II. Configure agents
######################################################################

#Step 1: distribute the certificates
#- CA public certificate: consul-agent-ca.pem
#- Consul agent public certificate: server1.dc1.consul.crt
#- Consul agent private key: server1.dc1.consul.key

#Step 2: configure servers   -> pod/consul-server-0
echo '
{
  "verify_incoming": true,
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "ca_file": "consul-agent-ca.pem",
  "cert_file": "server1.dc1.consul.crt",
  "key_file": "server1.dc1.consul.key",
  "ports": {
    "http": -1,
    "https": 8501
  }
}
' > /consul/config/consul-server.json

#Step 3: configure clients    -> /consul/config/consul-client.json
echo '
{
  "verify_incoming": true,
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "ca_file": "consul-agent-ca.pem",
  "cert_file": "client.dc1.consul.crt",
  "key_file": "client.dc1.consul.key",
  "ports": {
    "http": -1,
    "https": 8501
  }
}
' > /consul/config/consul-client.json

#Step 4: start Consul agents
