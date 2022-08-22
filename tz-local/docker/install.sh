#!/usr/bin/env bash

#cd /Volumes/workspace/tz/tz-eks-main/tz-local/docker
#set -x
shopt -s expand_aliases

export eks_project=eks-main
export eks_domain=tzcorp.com
export tz_project=eks-main
export vault_token=xxxxxxxx
export docker_user="doohee.hong"
export docker_passwd='xxxxxxxx'
#docker exec -it `docker ps | tail -n 1 | awk '{print $1}'` bash

docker login nexus.tzcorp.com:5000 -u="${docker_user}" -p="${docker_passwd}"
TAG=nexus.tzcorp.com:5000/${tz_project}:latest
#RMI=`docker images -a | grep -w "nexus.tzcorp.com:5000/${tz_project}" | grep latest | awk '{print $3}'`
#docker tag ${RMI} ${TAG}
#docker push ${TAG}
echo "######### ${TAG}"

#docker pull ${TAG}
cp -Rf docker-compose.yml docker-compose.yml_bak
sed -ie "s|tz-main|${TAG}|g" docker-compose.yml_bak
sed -ie "s|tz_main|${tz_project}|g" docker-compose.yml_bak
docker-compose -f docker-compose.yml_bak build
#docker-compose -f docker-compose.yml_bak build --no-cache
docker image ls
docker-compose -f docker-compose.yml_bak up -d
#docker-compose -f docker-compose.yml_bak down
#docker exec -it `docker ps | grep docker-${tz_project} | awk '{print $1}'` bash
docker exec -it `docker ps | grep docker_${tz_project} | awk '{print $1}'` bash

export vault_token=xxxxx
#bash /vagrant/tz-local/docker/vault.sh put devops-prod resources
bash /vagrant/tz-local/docker/init2.sh

exit 0

bash /vagrant/tz-local/docker/vault.sh put devops-prod eks-main resources
bash /vagrant/tz-local/docker/vault.sh get devops-prod eks-main resources



#docker container stop $(docker container ls -a -q) && docker system prune -a -f --volumes

