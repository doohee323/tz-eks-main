#!/bin/bash

# sh bootstrap.sh remove
if [[ "$1" == "remove" ]]; then
  docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` \
      bash /vagrant/scripts/eks_remove_all.sh
  if [[ $? != 0 ]]; then
    echo "failed to remove resources!"
    exit 1
  fi
  docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` \
      bash /vagrant/scripts/eks_remove_all.sh cleanTfFiles
  exit 0
fi

# sh bootstrap.sh
cd tz-local/docker
bash install.sh

export tz_project=eks-main-t
#docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` bash
docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` \
    bash /vagrant/tz-local/docker/init2.sh

exit 0

# install in docker
export docker_user="doohee323"
bash /vagrant/tz-local/docker/init2.sh

# remove all resouces
docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` bash
bash /vagrant/scripts/eks_remove_all.sh
bash /vagrant/scripts/eks_remove_all.sh cleanTfFiles

#docker container stop $(docker container ls -a -q) && docker system prune -a -f --volumes
