#!/usr/bin/env bash

## https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/add-user-role.html
source /root/.bashrc
#bash /vagrant/tz-local/resource/makeuser/eks/eks-users.sh
cd /vagrant/tz-local/resource/makeuser/eks

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

export AWS_DEFAULT_PROFILE="default"
aws sts get-caller-identity
kubectl -n kube-system get configmap aws-auth -o yaml
kubectl get node

kubectl create ns devops
kubectl create ns devops-dev
kubectl create ns consul
kubectl create ns vault

exit 0

