#!/usr/bin/env bash

cd /vagrant/tz-local/resource/docker-repo

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
dockerhub_id=$(prop 'project' 'dockerhub_id')
dockerhub_password=$(prop 'project' 'dockerhub_password')
docker_url=$(prop 'project' 'docker_url')

kubectl delete -f https://raw.githubusercontent.com/alexellis/registry-creds/master/manifest.yaml
kubectl apply -f https://raw.githubusercontent.com/alexellis/registry-creds/master/manifest.yaml

export DOCKER_USERNAME=$dockerhub_id
export PW=$dockerhub_password
export EMAIL=doohee323@gmail.com

kubectl delete secret registry-creds -n kube-system
kubectl create secret docker-registry registry-creds \
  --namespace kube-system \
  --docker-server=https://nexus.topzone.co.kr:5443/v2/ \
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$PW \
  --docker-email=$EMAIL

#kubectl delete secret registry-creds -n jenkins
#kubectl create secret docker-registry registry-creds \
#  --namespace jenkins \
#  --docker-server=https://nexus.topzone.co.kr:5000/v2/ \
#  --docker-username=$DOCKER_USERNAME \
#  --docker-password=$PW \
#  --docker-email=$EMAIL

#  --docker-server=https://nexus.topzone.co.kr:5000/v2/ \
#kubectl get secret registry-creds --output=yaml

kubectl delete -f clusterPullSecret.yaml
kubectl apply -f clusterPullSecret.yaml

#kubectl annotate ns jenkins alexellis.io/registry-creds.ignore=0 --overwrite
#kubectl annotate ns jenkins alexellis.io/registry-creds.ignore=1
#kubectl annotate ns devops-dev alexellis.io/registry-creds.ignore=0 --overwrite
