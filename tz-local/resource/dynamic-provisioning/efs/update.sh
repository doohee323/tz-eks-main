#!/usr/bin/env bash

#https://www.padok.fr/en/blog/efs-provisioner-kubernetes#create
#https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
#https://faun.pub/aws-eks-volumes-architecture-in-a-statefull-app-in-multiple-azs-6ca1b05f80eb
#https://www.44bits.io/ko/post/amazon-efs-on-kubernetes-by-using-efs-provisioner
#https://pseonghoon.github.io/post/k8s-and-nfs/

#bash /vagrant/tz-local/resource/dynamic-provisioning/efs/update.sh devops-dev c
cd /vagrant/tz-local/resource/dynamic-provisioning/efs

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)
#eks_role=$(aws iam list-roles --out=text | grep "${eks_project}" | grep "0000000" | head -n 1 | awk '{print $7}')
pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
eks_role=$(terraform output | grep cluster_iam_role_arn | awk '{print $3}' | tr "/" "\n" | tail -n 1)
popd
echo eks_role: ${eks_role}

shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

efs_name="tz-efs-${eks_project}"
echo "efs_name: ${efs_name}"
policy_name="efs_provisioner_policy_${eks_project}"
echo "policy_name: ${policy_name}"

NS=$1
if [[ "${NS}" == "" ]]; then
  NS=devops-dev
fi
SUBNET_CLASS=$2
if [[ "${SUBNET_CLASS}" == "" ]]; then
  SUBNET_CLASS=a
fi

VPC_ID=$(aws eks describe-cluster \
    --name ${eks_project} \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)
echo "VPC_ID: ${VPC_ID}"

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids ${VPC_ID} \
    --query "Vpcs[].CidrBlock" \
    --output text)
echo "cidr_range: ${cidr_range}"

security_group_id=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=${efs_name} \
    --query "SecurityGroups[*].{ID:GroupId}" \
    --output text)
echo "security_group_id: ${security_group_id}"

aws ec2 authorize-security-group-ingress \
    --group-id ${security_group_id} \
    --protocol tcp \
    --port 2049 \
    --cidr ${cidr_range}

#[ efs-provisioner ]###############################################################################################

eksctl delete iamserviceaccount \
    --cluster ${eks_project} \
    --namespace ${NS} \
    --name efs-provisioner-sa

eksctl create iamserviceaccount \
    --name efs-provisioner-sa \
    --namespace ${NS} \
    --cluster ${eks_project} \
    --region ${AWS_REGION} \
    --attach-policy-arn arn:aws:iam::${aws_account_id}:policy/${policy_name} \
    --override-existing-serviceaccounts \
    --approve

file_system_id=$(aws efs create-file-system \
    --region ${AWS_REGION} \
    --performance-mode generalPurpose \
    --tags Key=Name,Value=${efs_name}-${NS} \
    --query 'FileSystemId' \
    --output text)
echo "file_system_id: ${file_system_id}"  # fs-2d20aa4d
#aws efs delete-file-system \
#    --file-system-id ${file_system_id}
aws efs describe-file-systems \
    --file-system-id ${file_system_id}

aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].{SubnetId: SubnetId,AvailabilityZone: AvailabilityZone,CidrBlock: CidrBlock}' \
    --output table

subnet_id=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --filters "Name=tag:Name,Values=${eks_project}-vpc-private-${AWS_REGION}${SUBNET_CLASS}" \
    --query 'Subnets[*].{SubnetId: SubnetId}' \
    --output text | head -n 1)
echo "subnet_id: ${subnet_id}"

aws efs create-mount-target \
    --file-system-id ${file_system_id} \
    --subnet-id ${subnet_id} \
    --security-groups ${security_group_id}

sleep 120

cp values.yaml values.yaml_bak
sed -i "s/file_system_id/${file_system_id}/g" values.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" values.yaml_bak
sed -i "s/NS/${NS}/g" values.yaml_bak
if [[ "${NS/*-dev/}" == "" ]]; then
  TEAM=${NS/-dev/}
  STAGING="dev"
else
  TEAM=${NS}
  STAGING="prod"
fi
sed -i "s/TEAM/${TEAM}/g" values.yaml_bak
sed -i "s/STAGING/${STAGING}/g" values.yaml_bak
sed -i "s/aws_account_id/${aws_account_id}/g" values.yaml_bak
sed -i "s/eks_role/${eks_role}/g" values.yaml_bak
helm repo add stable https://charts.helm.sh/stable
helm repo update
# https://github.com/helm/charts/tree/master/stable/efs-provisioner
helm uninstall efs-provisioner-${NS} -n ${NS}
helm upgrade --debug --install --reuse-values -f values.yaml_bak \
    efs-provisioner-${NS} stable/efs-provisioner -n ${NS} \
    --version "0.13.2"

eksctl create iamserviceaccount \
    --name efs-provisioner-sa \
    --namespace ${NS} \
    --cluster ${eks_project} \
    --region ${AWS_REGION} \
    --attach-policy-arn arn:aws:iam::${aws_account_id}:policy/${policy_name} \
    --override-existing-serviceaccounts \
    --approve

sleep 60

cp efs_test.yaml efs_test.yaml_bak
sed -i "s/NS/${NS}/g" efs_test.yaml_bak
sed -i "s/TEAM/${TEAM}/g" efs_test.yaml_bak
sed -i "s/STAGING/${STAGING}/g" efs_test.yaml_bak
kubectl delete -f efs_test.yaml_bak -n ${NS} --grace-period=0 --force
kubectl apply -f efs_test.yaml_bak -n ${NS}

#aws eks describe-cluster --name eks-main --query "cluster.identity.oidc.issuer" --output text
#aws iam list-open-id-connect-providers | grep 599A2C9BF622289E39164597D4E9C37C
#eksctl utils associate-iam-oidc-provider --cluster eks-main --approve
