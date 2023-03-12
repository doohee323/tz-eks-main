#!/bin/bash

if [[ "$1" == "remove" ]]; then
  bash eks_remove_all.sh
  exit 0
fi

cd tz-local/docker
bash install.sh

export tz_project=eks-main-s
#docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` bash
docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` \
    bash /vagrant/tz-local/docker/init2.sh

exit 0

# install in docker
export docker_user="doohee323"
export docker_passwd="hdh971097"
bash /vagrant/tz-local/docker/init2.sh

# remove all resouces
docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` bash
bash /vagrant/scripts/eks_remove_all.sh
bash /vagrant/scripts/eks_remove_all.sh cleanTfFiles
