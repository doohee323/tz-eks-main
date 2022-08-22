#!/usr/bin/env bash

PROJECT_BASE='/vagrant/terraform-aws-eks/workspace/base'

bash /vagrant/tz-local/docker/vault.sh get devops-prod ${tz_project} resources
cd /vagrant && tar xvfz resources.zip

sudo mkdir -p /home/vagrant/.aws
sudo cp -Rf /vagrant/resources/config /home/vagrant/.aws/config
sudo cp -Rf /vagrant/resources/credentials /home/vagrant/.aws/credentials
sudo cp -Rf /vagrant/resources/project /home/vagrant/.aws/project
sudo chown -Rf vagrant:vagrant /home/vagrant/.aws
sudo rm -Rf /root/.aws
sudo cp -Rf /home/vagrant/.aws /root/.aws

sudo mkdir -p /home/vagrant/.kube
sudo cp -Rf /vagrant/resources/kubeconfig_${eks_project} /home/vagrant/.kube/config
sudo chown -Rf vagrant:vagrant /home/vagrant/.kube
sudo rm -Rf /root/.kube
sudo cp -Rf /home/vagrant/.kube /root/.kube

git config --global --add safe.directory '*'

cp -Rf /vagrant/resources/${eks_project} ${PROJECT_BASE}
cp -Rf /vagrant/resources/${eks_project}.pub ${PROJECT_BASE}
cp -Rf /vagrant/resources/kubeconfig_${eks_project} ${PROJECT_BASE}

cd ${PROJECT_BASE}
if [ ! -d "${PROJECT_BASE}/.terraform" ]; then
  ############################################################
  # make aws credentials
  ############################################################
  chmod -Rf 600 ${eks_project}*
  mkdir /home/vagrant/.ssh
  cp -Rf ${eks_project}* /home/vagrant/.ssh
  cp -Rf ${eks_project}* /vagrant/resources
  chown -Rf vagrant:vagrant /home/vagrant/.ssh
  chown -Rf vagrant:vagrant /vagrant/resources

  git checkout /vagrant/terraform-aws-eks/local.tf
  git checkout ${PROJECT_BASE}/locals.tf
  git checkout ${PROJECT_BASE}/variables.tf

  echo "= [terraform] =========================================="

  sed -i "s/aws_region/${aws_region}/g" /vagrant/terraform-aws-eks/local.tf
  sed -i "s/eks_project/${eks_project}/g" /vagrant/terraform-aws-eks/local.tf
  sed -i "s/aws_region/${aws_region}/g" ${PROJECT_BASE}/locals.tf
  sed -i "s/eks_project/${eks_project}/g" ${PROJECT_BASE}/locals.tf
  sed -i "s/aws_account_id/${aws_account_id}/g" ${PROJECT_BASE}/locals.tf

  rm -Rf ${PROJECT_BASE}/lb2.tf

#  terraform init
#  terraform plan
##  terraform plan | sed 's/\x1b\[[0-9;]*m//g' > a.txt
#  terraform apply -auto-approve

  aws_account_id=$(aws sts get-caller-identity --query Account --output text)
#  eks_role=$(aws iam list-roles --out=text | grep "${eks_project}" | grep "0000000" | head -n 1 | awk '{print $7}')
#  echo eks_role: ${eks_role}

  worker_groups_role=$(terraform output | grep worker_groups_role | awk '{print $3}' | awk '{print $2}')
  echo worker_groups_role: ${worker_groups_role}
  cluster_iam_role=$(terraform output | grep cluster_iam_role_arn | awk '{print $3}' | tr "/" "\n" | tail -n 1)
  echo cluster_iam_role: ${cluster_iam_role}
#  cluster_autoscaler_role=$(terraform output | grep cluster_autoscaler_role | awk '{print $3}')
#  echo cluster_autoscaler_role: ${cluster_autoscaler_role}

  sed -i "s/eks-main_role/${cluster_iam_role}/g" ${PROJECT_BASE}/locals.tf
  sed -i "s/eks-main_role/${cluster_iam_role}/g" ${PROJECT_BASE}/variables.tf

  cp -Rf lb2.tf_ori lb2.tf

#  terraform init
#  terraform plan
#  terraform apply -auto-approve

  S3_BUCKET=$(terraform output | grep s3-bucket | awk '{print $3}')
  echo $S3_BUCKET > s3_bucket_id
  # terraform destroy -auto-approve
fi

