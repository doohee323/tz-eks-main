#!/bin/bash

bash tz-local/docker/install.sh
export tz_project=eks-main-t

# bash bootstrap.sh remove
if [[ "$1" == "remove" ]]; then
  docker exec -it `docker ps | grep devops-utils | awk '{print $1}'` \
      bash /vagrant/tz-local/docker/init2.sh && bash /vagrant/scripts/eks_remove_all.sh
  if [[ $? != 0 ]]; then
    echo "failed to remove resources!"
    exit 1
  fi
  docker exec -it `docker ps | grep devops-utils | awk '{print $1}'` \
      bash /vagrant/scripts/eks_remove_all.sh cleanTfFiles
  exit 0
fi

# bash bootstrap.sh
#docker exec -it `docker ps | grep devops-utils | awk '{print $1}'` bash
docker exec -it `docker ps | grep devops-utils | awk '{print $1}'` \
    bash /vagrant/tz-local/docker/init2.sh

exit 0

# install in docker
export docker_user="doohee323"
bash /vagrant/tz-local/docker/init2.sh

# remove all resources
docker exec -it `docker ps | grep devops-utils | awk '{print $1}'` bash
bash /vagrant/scripts/eks_remove_all.sh
bash /vagrant/scripts/eks_remove_all.sh cleanTfFiles

#docker container stop $(docker container ls -a -q) && docker system prune -a -f --volumes
