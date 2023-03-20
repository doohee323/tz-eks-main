#!/usr/bin/env bash

PROJECT_BASE='/vagrant/terraform-aws-eks/workspace/base'
cd ${PROJECT_BASE}

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
aws_region=$(prop 'config' 'region')
eks_project=$(prop 'project' 'project')

bash /vagrant/tz-local/resource/docker-repo/install.sh
bash /vagrant/tz-local/resource/persistent-storage/install.sh
bash /vagrant/tz-local/resource/ingress_nginx/install.sh
bash /vagrant/tz-local/resource/autoscaler/install.sh

bash /vagrant/tz-local/resource/consul/install.sh
bash /vagrant/tz-local/resource/vault/helm/install.sh
bash /vagrant/tz-local/resource/vault/data/vault_user.sh
bash /vagrant/tz-local/resource/vault/vault-injection/install.sh
bash /vagrant/tz-local/resource/vault/vault-injection/update.sh

bash /vagrant/tz-local/resource/argocd/helm/install.sh
bash /vagrant/tz-local/resource/jenkins/helm/install.sh

exit 0

