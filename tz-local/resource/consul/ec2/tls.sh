#!/usr/bin/env bash

# https://learn.hashicorp.com/tutorials/consul/deployment-guide#configure-consul-agents

#set -x
shopt -s expand_aliases
alias k='kubectl'

KEYGEN=$(consul keygen)

#Create the Certificate Authority
consul tls ca create

#Create the certificates
consul tls cert create -server -dc tz-dc

#create client certificates
consul tls cert create -client -dc tz-dc

#Distribute the certificates to agents
scp consul-agent-ca.pem \
  tz-dc-server-consul-0.pem \
  tz-dc-server-consul-0-key.pem \
  <USER>@<PUBLIC_IP>:/etc/consul.d/

scp consul-agent-ca.pem \
  tz-dc-client-consul-0.pem \
  tz-dc-client-consul-0-key.pem \
  <USER>@<PUBLIC_IP>:/etc/consul.d/

# Configure Consul agents
sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

echo '
datacenter = "tz-dc"
data_dir = "/opt/consul"
encrypt = "KEYGEN"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/tz-dc-server-consul-0.pem"
key_file = "/etc/consul.d/tz-dc-server-consul-0-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
' > /etc/consul.d/consul.hcl
sed -i 's/KEYGEN/${KEYGEN}/g' /etc/consul.d/consul.hcl

#Enable Consul ACLs
echo '
acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}
' > /etc/consul.d/consul.hcl

