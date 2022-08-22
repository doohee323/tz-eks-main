#!/usr/bin/env bash

# https://learn.hashicorp.com/tutorials/consul/access-control-setup-production#create-the-initial-bootstrap-token

#set -x
shopt -s expand_aliases
alias k='kubectl'

cat > secure-dc1.yaml <<EOF
# Choose an optional name for the datacenter
global:
#  name: consul
  enabled: true
  datacenter: tz-dc

  acls:
    manageSystemACLs: true

# Enable the Consul Web UI via a NodePort
ui:
  service:
    type: 'ClusterIP'

# Enable Connect for secure communication between nodes
connectInject:
  enabled: true
# Enable CRD Controller
controller:
  enabled: true

client:
  enabled: true

# Use only one Consul server for local development
server:
  replicas: 3
  storage: 100Mi
  disruptionBudget:
    enabled: true
    maxUnavailable: 0
  service:
    enabled: true
EOF

helm upgrade consul hashicorp/consul -f ./secure-dc1.yaml -n consul --wait

#watch kubectl get pods
export CONSUL_HTTP_ADDR="localhost:8500"
consul members

consul acl bootstrap




