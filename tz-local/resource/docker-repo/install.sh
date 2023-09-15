#!/usr/bin/env bash

source /root/.bashrc
cd /vagrant/tz-local/resource/docker-repo

#set -x
shopt -s expand_aliases
alias k='kubectl'

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
dockerhub_id=$(prop 'project' 'dockerhub_id')
dockerhub_password=$(prop 'project' 'dockerhub_password')
docker_url=$(prop 'project' 'docker_url')

apt-get update -y
apt-get -y install docker.io jq
usermod -G docker ubuntu
chown -Rf ubuntu:ubuntu /var/run/docker.sock

mkdir -p ~/.docker
docker login -u="${dockerhub_id}" -p="${dockerhub_password}" ${docker_url}

sleep 2

cat ~/.docker/config.json
#{"auths":{"https://nexus.shoptoolstest.co.kr:5443/v2/":{"username":"devops","password":"devops!323","email":"doohee323@gmail.com","auth":"ZGV2b3BzOmRldm9wcyEzMjM="}}}
mkdir -p /home/ubuntu/.docker
cp -Rf ~/.docker/config.json /home/ubuntu/.docker/config.json
chown -Rf ubuntu:ubuntu /home/ubuntu/.docker

kubectl delete secret registry-creds -n kube-system
kubectl create secret generic registry-creds -n kube-system \
    --from-file=.dockerconfigjson=/home/ubuntu/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson

#  --docker-server=https://nexus.shoptoolstest.co.kr:5000/v2/ \
#kubectl get secret registry-creds --output=yaml

kubectl delete -f clusterPullSecret.yaml
kubectl apply -f clusterPullSecret.yaml

PROJECTS=(argocd consul jenkins default devops devops-dev monitoring vault)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    echo "===================== ${item}"
    kubectl delete secret registry-creds -n ${item}
    kubectl create secret generic registry-creds \
      -n ${item} \
      --from-file=.dockerconfigjson=/home/ubuntu/.docker/config.json \
      --type=kubernetes.io/dockerconfigjson
  fi
done

kubectl delete secret docker-config -n jenkins
kubectl create secret generic docker-config \
     -n jenkins \
    --from-file=config.json=/home/ubuntu/.docker/config.json

#echo "
#apiVersion: v1
#kind: Secret
#metadata:
#  name: registry-creds
#data:
#  .dockerconfigjson: docker-config
#type: kubernetes.io/dockerconfigjson
#" > docker-config.yaml
#
#DOCKER_CONFIG=$(cat /home/ubuntu/.docker/config.json | base64 | tr -d '\r')
#DOCKER_CONFIG=$(echo $DOCKER_CONFIG | sed 's/ //g')
#echo "${DOCKER_CONFIG}"
#cp docker-config.yaml docker-config.yaml_bak
#sed -i "s/DOCKER_CONFIG/${DOCKER_CONFIG}/g" docker-config.yaml_bak
#k apply -f docker-config.yaml_bak

kubectl get secret registry-creds --output=yaml
kubectl get secret registry-creds -n vault --output=yaml

kubectl get secret registry-creds --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode

exit 0

spec:
  containers:
  - name: private-reg-container
    image: <your-private-image>
  imagePullSecrets:
    - name: registry-creds

docker login nexus.shoptoolstest.co.kr:5443
docker pull nexus.shoptoolstest.co.kr:5443/devops-utils2:latest
