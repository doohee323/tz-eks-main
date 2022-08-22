#!/usr/bin/env bash

#set -x

## https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/add-user-role.html
#bash /vagrant/tz-local/resource/makeuser/eks/eks-users.sh

cd /vagrant/tz-local/resource/makeuser/eks

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')

aws_account_id=$(aws sts get-caller-identity --query Account --output text)

export AWS_DEFAULT_PROFILE="default"
aws sts get-caller-identity
kubectl -n kube-system get configmap aws-auth -o yaml
kubectl get node

kubectl create ns devops
kubectl create ns devops-dev
kubectl create ns common
kubectl create ns common-dev
kubectl create ns devops
kubectl create ns devops-dev
kubectl create ns datateam
kubectl create ns datateam-dev
kubectl create ns extension
kubectl create ns extension-dev
kubectl create ns devops
kubectl create ns devops-dev
kubectl create ns ssakdook
kubectl create ns ssakdook-dev
kubectl create ns consul
kubectl create ns vault

#eks_role=$(aws iam list-roles --out=text | grep "${eks_project}2" | grep "0000000" | head -n 1 | awk '{print $7}')
pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
eks_role=$(terraform output | grep cluster_iam_role_arn | awk '{print $3}' | tr "/" "\n" | tail -n 1 | sed 's/"//g')
popd
echo eks_role: ${eks_role}
aws iam create-policy --policy-name ${eks_project}-ecr-policy --policy-document file://eks-policy.json
cp eks-role.json eks-role.json_bak
sed -i "s/aws_account_id/${aws_account_id}/g" eks-role.json_bak
aws iam update-assume-role-policy --role-name ${eks_role} --policy-document file://eks-role.json_bak
aws iam attach-role-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/${eks_project}-ecr-policy --role-name ${eks_role}

#ec2_role=$(aws iam list-roles --out=text | grep "${eks_project}2" | grep "000000" | tail -n 1 | awk '{print $7}')
pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
ec2_role=$(terraform output | grep worker_groups_role | awk '{print $3}' | tr "/" "\n" | tail -n 1 | sed 's/"//g')
popd
echo ec2_role: ${ec2_role}
cp eks-roles-configmap.yaml eks-roles-configmap.yaml_bak
sed -i "s/aws_account_id/${aws_account_id}/g" eks-roles-configmap.yaml_bak
sed -i "s/eks_role/${eks_role}/g" eks-roles-configmap.yaml_bak
sed -i "s/ec2_role/${ec2_role}/g" eks-roles-configmap.yaml_bak
kubectl apply -f eks-roles-configmap.yaml_bak

# add a eks-users
#kubectl delete -f eks-roles.yaml
#kubectl delete -f eks-rolebindings.yaml
#cp eks-roles-configmap.yaml eks-roles-configmap.yaml_bak
#sed -i "s/aws_account_id/${aws_account_id}/g" eks-roles-configmap.yaml_bak
#sed -i "s/eks_project/${eks_project}/g" eks-roles-configmap.yaml_bak
#kubectl delete -f eks-roles-configmap.yaml_bak
#kubectl delete -f eks-console-full-access.yaml
#kubectl delete -f eks-console-restricted-access.yaml

#cp eks-roles-configmap-min.yaml eks-roles-configmap-min.yaml_bak
#sed -i "s/eks_project/${eks_project}/g" eks-roles-configmap-min.yaml_bak
#kubectl delete -f eks-roles-configmap-min.yaml_bak
#kubectl apply -f eks-roles-configmap-min.yaml_bak

#kubectl apply -f eks-roles.yaml
#kubectl apply -f eks-rolebindings.yaml
#kubectl apply -f eks-roles-configmap.yaml_bak
#kubectl apply -f eks-console-full-access.yaml

exit 0

vault secrets enable aws
vault secrets enable consul
vault auth enable kubernetes
vault secrets enable database
vault secrets enable pki
vault secrets enable -version=2 kv
vault secrets enable -path=kv kv
vault secrets enable -path=secret/ kv
vault auth enable userpass

aws configure --profile devops
export AWS_DEFAULT_PROFILE="devops"
aws sts get-caller-identity


kubectl edit -n kube-system configmap/aws-auth
kubectl get rolebindings -A
kubectl get clusterrolebindings
aws sts get-caller-identity


kubectl get node
kubectl get pods -n devops
kubectl get all -n devops

kubectl get context

kubectl config get-contexts
kubectl config view
kubectl config set-context devops-dev \
  --cluster=eks_eks-main \
  --namespace=devops-dev \
  --user=doogee.hong

kubectl config set-context devops \
  --cluster=eks_eks-main \
  --user=doogee.hong

kubectl config use-context devops


kubectl config use-context devops-dev
#kubectx devops-dev
kubectl get pods -n devops-dev
kubectl config use-context eks_eks-main
kubectl config delete-context devops-dev

kubectl get sa -n default


kubectl get clusterroles.rbac.authorization.k8s.io --all-namespaces
kubectl get roles.rbac.authorization.k8s.io --all-namespaces




exit 0

