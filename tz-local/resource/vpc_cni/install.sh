#!/usr/bin/env bash

#https://docs.aws.amazon.com/eks/latest/userguide/cni-iam-role.html

source /root/.bashrc
#bash /vagrant/tz-local/resource/vpc_cni/install.sh
cd /vagrant/tz-local/resource/vpc_cni

#set -x
shopt -s expand_aliases

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
admin_password=$(prop 'project' 'admin_password')
github_token=$(prop 'project' 'github_token')
basic_password=$(prop 'project' 'basic_password')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

alias k='kubectl --kubeconfig ~/.kube/config'
#alias k="kubectl --kubeconfig ~/.kube/kubeconfig_${eks_project}"

aws eks describe-cluster --name ${eks_project} | grep ipFamily
issuerUrl=$(aws eks describe-cluster --name ${eks_project} --query "cluster.identity.oidc.issuer" --output text)
OIDC_URL=$(echo ${issuerUrl} | sed 's/https:\/\///g')
echo "OIDC_URL: ${OIDC_URL}"

cp vpc-cni-trust-policy.json vpc-cni-trust-policy.json_bak
sed -i "s|OIDC_URL|${OIDC_URL}|g" vpc-cni-trust-policy.json_bak
sed -i "s|aws_account_id|${aws_account_id}|g" vpc-cni-trust-policy.json_bak

aws iam detach-role-policy \
  --role-name AmazonEKSVPCCNIRole-${eks_project} \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy-${eks_project}

aws iam delete-role --role-name AmazonEKSVPCCNIRole-${eks_project}
aws iam create-role \
  --role-name AmazonEKSVPCCNIRole-${eks_project} --assume-role-policy-document file://vpc-cni-trust-policy.json_bak

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
  --role-name AmazonEKSVPCCNIRole-${eks_project}

kubectl annotate serviceaccount \
    -n kube-system aws-node \
    eks.amazonaws.com/role-arn=arn:aws:iam::${aws_account_id}:role/AmazonEKSVPCCNIRole-${eks_project}

# set enabled
# https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/cni-increase-ip-addresses.html
#kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=false
#kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true

kubectl delete pods -n kube-system -l k8s-app=aws-node
kubectl get pods -n kube-system -l k8s-app=aws-node

#aws iam detach-role-policy \
#  --role-name AmazonEKSVPCCNIRole-${eks_project} \
#  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy-${eks_project}
