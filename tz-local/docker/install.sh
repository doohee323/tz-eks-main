#!/usr/bin/env bash

cd /Volumes/workspace/etc/tz-eks-main/tz-local/docker
#set -x
#shopt -s expand_aliases

export eks_project=eks-main-t
export eks_domain=tzcorp.com
export tz_project=devops-utils
export vault_token=xxxxx
export docker_user="doohee323"
export docker_passwd="hdh971097"
#docker exec -it `docker ps | tail -n 1 | awk '{print $1}'` bash

#docker login nexus.tzcorp.com:5000 -u="${docker_user}" -p="${docker_passwd}"
docker login -u="${docker_user}" -p="${docker_passwd}"
#TAG=nexus.tzcorp.com:5000/${tz_project}:latest
TAG=${docker_user}/${tz_project}:latest
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
docker exec -it `docker ps | grep docker-${tz_project} | awk '{print $1}'` bash
#docker exec -it `docker ps | grep docker_${tz_project} | awk '{print $1}'` bash

#bash /vagrant/tz-local/docker/vault.sh put devops-prod resources
export tz_project=eks-main-t
bash /vagrant/tz-local/docker/init2.sh

exit 0

cd /vagrant
bash /vagrant/tz-local/docker/vault.sh put devops-prod eks-main-t resources
bash /vagrant/tz-local/docker/vault.sh get devops-prod eks-main-t resources

#docker container stop $(docker container ls -a -q) && docker system prune -a -f --volumes

terraform apply -target=aws_eks_node_group.workers
terraform apply -target=aws-modules.eks

terraform apply -target=aws_iam_role.k8sDev \
  -target=aws_iam_role.k8sAdmin \
  -target=aws_iam_policy.k8sDev \
  -target=aws_iam_policy.k8sAdmin \
  -target=aws_iam_group_policy.k8sDev_policy \
  -target=aws_iam_group_policy.k8sAdmin_policy \
  -target=aws_iam_group_membership.k8sDev \
  -target=aws_iam_group_membership.k8sAdmin \
  -target=aws_iam_group.k8sDev \
  -target=aws_iam_group.k8sAdmin \
  -target=aws_iam_user.k8sAdmin \
  -target=aws_iam_user.k8sDev

terraform apply -target=aws_iam_user_policy_attachment.doohee-hong \
  -target=aws_iam_user_policy_attachment.doogee-hong

terraform apply -target=module.eks.kubernetes_config_map.aws_auth

kubernetes_config_map.aws_auth
terraform apply -target=kubernetes_config_map.aws_auth,

terraform force-unlock xxx

pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
cluster_iam_role_name=$(terraform output | grep cluster_iam_role_name | awk '{print $3}' | sed 's/\"//g')
popd
echo ${cluster_iam_role_name}

