#!/usr/bin/env bash

cd /vagrant/tz-local/resource/docker-repo

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')

kubectl apply -f https://raw.githubusercontent.com/alexellis/registry-creds/master/manifest.yaml

export DOCKER_USERNAME=tzdevops
export PW=${admin_password}
export EMAIL=devops@tz.gg

kubectl create secret docker-registry tz-registrykey \
  --namespace kube-system \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$PW \
  --docker-email=$EMAIL

kubectl apply -f clusterPullSecret.yaml

kubectl annotate ns datateam-dev alexellis.io/registry-creds.ignore=1
#kubectl annotate ns datateam-dev alexellis.io/registry-creds.ignore=0 --overwrite