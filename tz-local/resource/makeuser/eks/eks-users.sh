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

pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
eks_role=$(terraform output | grep cluster_iam_role_arn | awk '{print $3}' | tr "/" "\n" | tail -n 1 | sed 's/"//g')
popd
echo eks_role: ${eks_role}
#aws iam create-policy --policy-name ${eks_project}-ecr-policy --policy-document file://eks-policy.json
#cp eks-role.json eks-role.json_bak
#sed -i "s/aws_account_id/${aws_account_id}/g" eks-role.json_bak
#aws iam update-assume-role-policy --role-name ${eks_role} --policy-document file://eks-role.json_bak
#aws iam attach-role-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/${eks_project}-ecr-policy --role-name ${eks_role}

cp eks-roles-configmap.yaml eks-roles-configmap.yaml_bak
sed -i "s/aws_account_id/${aws_account_id}/g" eks-roles-configmap.yaml_bak
sed -i "s/eks_role/${eks_role}/g" eks-roles-configmap.yaml_bak
sed -i "s/ec2_role/${eks_role}/g" eks-roles-configmap.yaml_bak
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

