#!/usr/bin/env bash

# sudo bash /vagrant/scripts/eks_addtion.sh

PROJECT_BASE='/vagrant/terraform-aws-eks/workspace/base'
cd ${PROJECT_BASE}

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
aws_region=$(prop 'config' 'region')
eks_project=$(prop 'project' 'project')

bash /vagrant/tz-local/resource/makeuser/eks/eks-users.sh

bash /vagrant/tz-local/resource/docker-repo/install.sh
bash /vagrant/tz-local/resource/local-dns/install.sh
bash /vagrant/tz-local/resource/autoscaler/install.sh

# bash /vagrant/tz-local/resource/nginx_ingress/install.sh
bash /vagrant/tz-local/resource/elb-controller/install.sh
bash /vagrant/tz-local/resource/ingress_nginx/install.sh
bash /vagrant/tz-local/resource/elb-controller/update.sh
#bash /vagrant/tz-local/resource/ingress_nginx/internal/install.sh

exit 0

bash /vagrant/tz-local/resource/consul/install.sh
bash /vagrant/tz-local/resource/vault/helm/install.sh
bash /vagrant/tz-local/resource/vault/data/vault_user.sh
bash /vagrant/tz-local/resource/vault/vault-injection/install.sh
bash /vagrant/tz-local/resource/vault/vault-injection/update.sh

bash /vagrant/tz-local/resource/argocd/install.sh

bash /vagrant/tz-local/resource/persistent-storage/install.sh
#bash /vagrant/tz-local/resource/persistent-storage/devops-web/update.sh

bash /vagrant/tz-local/resource/k8s-backup/install.sh

bash /vagrant/tz-local/resource/monitoring/install.sh
bash /vagrant/tz-local/resource/monitoring/prometheus/install.sh
bash /vagrant/tz-local/resource/monitoring/prometheus/update.sh

#bash /vagrant/tz-local/resource/datadog/install.sh

#bash /vagrant/tz-local/resource/jenkins/helm/install.sh

#bash /vagrant/tz-local/resource/oidc/install.sh

exit 0

cp -Rf ../addition/addition_* .

terraform init
terraform apply -auto-approve

shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

echo "### [ ping test to jenkins ] ###############################################################"
readarray -t <<< $(aws ec2 describe-instances --region ${aws_region} --filters Name=tag:Name,Values=tz-jenkins | grep 'IpAddress' | head -n 2  | cut -d ':' -f2 | sed 's/ //g;s/,//g;s/\"//g')
private_ip=${MAPFILE[0]}
public_ip=${MAPFILE[1]}
echo ssh -n -i ${eks_project} ubuntu@${public_ip} "ping -c 4 ${private_ip} | grep ttl"
echo kubectl run -it busybox --image=busybox --restart=Never --rm -- ping -c 4 ${private_ip} | grep ttl
kubectl run -it busybox --image=busybox --restart=Never --rm -- ping -c 4 ${private_ip} | grep ttl

echo "### [ telnet test to rds ] ###############################################################"
#URL="postback-dev.cluster-ro-c01spz81v11d.ap-northeast-2.rds.amazonaws.com"
#echo kubectl run -it busybox --image=busybox --restart=Never --rm -- ping -c 4 ${URL} | grep ttl
#kubectl run -it busybox --image=busybox --restart=Never --rm -- ping -c 4 ${URL} | grep ttl

echo "### [ backup_s3 ] ###############################################################"
#bash /vagrant/scripts/backup_s3.sh backup
