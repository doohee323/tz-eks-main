#!/usr/bin/env bash

cd tz-local/docker

export eks_project=eks-main-t
export eks_domain=t1zone.net
export tz_project=devops-utils

TAG=${docker_user}/${tz_project}:latest

cp -Rf docker-compose.yml docker-compose.yml_bak
sed -ie "s|tz-main|${TAG}|g" docker-compose.yml_bak
sed -ie "s|tz_main|${tz_project}|g" docker-compose.yml_bak
docker-compose -f docker-compose.yml_bak build
docker-compose -f docker-compose.yml_bak up -d
#docker-compose -f docker-compose.yml_bak down
#docker exec -it `docker ps | grep docker-${tz_project} | awk '{print $1}'` bash

exit 0
