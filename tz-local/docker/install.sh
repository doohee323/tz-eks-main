#!/usr/bin/env bash

cd tz-local/docker

export docker_user=746446553436
export aws_region=ap-northeast-2
export eks_project=eks-main-t
export eks_domain=shoptoolstest.co.kr
export tz_project=devops-utils
dockerhub_id=devops
dockerhub_password=
docker_url=nexus.shoptoolstest.co.kr:5443

#DOCKER_ID=${docker_user}.dkr.ecr.${aws_region}.amazonaws.com
doDOCKER_ID=$cker_url

TAG=${DOCKER_ID}/${tz_project}:latest

#aws_account_id=$(aws sts get-caller-identity --query Account --output text)
#aws ecr get-login-password --region ${aws_region} \
#      | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com
docker login -u="${dockerhub_id}" -p="${dockerhub_password}" ${docker_url}

cp -Rf docker-compose.yml docker-compose.yml_bak
sed -ie "s|tz-main|${TAG}|g" docker-compose.yml_bak
sed -ie "s|tz_main|${tz_project}|g" docker-compose.yml_bak
# --no-cache
docker-compose -f docker-compose.yml_bak build
docker-compose -f docker-compose.yml_bak up -d
#docker-compose -f docker-compose.yml_bak down
sleep 10
docker exec -it `docker ps | grep docker-${tz_project} | awk '{print $1}'` bash
#docker exec -it docker_devops-utils_1 bash
export docker_user="746446553436"
bash /vagrant/tz-local/docker/init2.sh

exit 0


