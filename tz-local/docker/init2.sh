#!/usr/bin/env bash

PROJECT_BASE='/vagrant/terraform-aws-eks/workspace/base'

cd /vagrant
bash /vagrant/tz-local/docker/vault.sh get devops-prod ${tz_project} resources
tar xvfz resources.zip && rm -Rf resources.zip

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

  echo "= [terraform] =========================================="

  rm -Rf ${PROJECT_BASE}/lb2.tf

#  terraform init
#  terraform plan -var-file=".auto.tfvars"
##  terraform plan | sed 's/\x1b\[[0-9;]*m//g' > a.txt
#  terraform apply -var-file=".auto.tfvars" -auto-approve

  cp -Rf lb2.tf_ori lb2.tf

#  terraform init
#  terraform plan -var-file=".auto.tfvars"
#  terraform apply -var-file=".auto.tfvars" -auto-approve
fi

