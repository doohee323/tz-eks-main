#!/usr/bin/env bash

#https://kim-dragon.tistory.com/157
#https://aws.amazon.com/ko/premiumsupport/knowledge-center/eks-multiple-cidr-ranges/
#https://tf-eks-workshop.workshop.aws/500_eks-terraform-workshop/570_advanced-networking/secondary_cidr/configure-cni.html
#https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/managing-vpc-cni.html

#bash /vagrant/tz-local/resource/2nd_cidr/install.sh
cd /vagrant/tz-local/resource/2nd_cidr

#set -x
shopt -s expand_aliases

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
admin_password=$(prop 'project' 'admin_password')
github_token=$(prop 'project' 'github_token')
basic_password=$(prop 'project' 'basic_password')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

alias k='kubectl --kubeconfig ~/.kube/config'
#alias k="kubectl --kubeconfig ~/.kube/kubeconfig_${eks_project}"

vpc_name="${eks_project}-vpc"
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${vpc_name} | jq -r '.Vpcs[].VpcId')
echo ${VPC_ID}

aws ec2 associate-vpc-cidr-block --vpc-id $VPC_ID --cidr-block 100.64.0.0/16
aws ec2 describe-availability-zones --region ${AWS_REGION} --query 'AvailabilityZones[*].ZoneName'

export AZ1=ap-northeast-2a
export AZ2=ap-northeast-2b
export AZ3=ap-northeast-2c
export AZ4=ap-northeast-2d

CUST_SNET1=$(aws ec2 create-subnet --cidr-block 100.64.0.0/19 --vpc-id $VPC_ID --availability-zone $AZ1 | jq -r .Subnet.SubnetId)
CUST_SNET2=$(aws ec2 create-subnet --cidr-block 100.64.32.0/19 --vpc-id $VPC_ID --availability-zone $AZ2 | jq -r .Subnet.SubnetId)
CUST_SNET3=$(aws ec2 create-subnet --cidr-block 100.64.64.0/19 --vpc-id $VPC_ID --availability-zone $AZ3 | jq -r .Subnet.SubnetId)
CUST_SNET4=$(aws ec2 create-subnet --cidr-block 100.64.96.0/19 --vpc-id $VPC_ID --availability-zone $AZ4 | jq -r .Subnet.SubnetId)

aws ec2 create-tags --resources $CUST_SNET1 --tags Key=Name,Value=${eks_project}-vpc-secondary-ap-northeast-2a
aws ec2 create-tags --resources $CUST_SNET2 --tags Key=Name,Value=${eks_project}-vpc-secondary-ap-northeast-2b
aws ec2 create-tags --resources $CUST_SNET3 --tags Key=Name,Value=${eks_project}-vpc-secondary-ap-northeast-2c
aws ec2 create-tags --resources $CUST_SNET4 --tags Key=Name,Value=${eks_project}-vpc-secondary-ap-northeast-2d

aws ec2 create-tags --resources $CUST_SNET1 --tags Key=kubernetes.io/cluster/${eks_project},Value=shared
aws ec2 create-tags --resources $CUST_SNET2 --tags Key=kubernetes.io/cluster/${eks_project},Value=shared
aws ec2 create-tags --resources $CUST_SNET3 --tags Key=kubernetes.io/cluster/${eks_project},Value=shared
aws ec2 create-tags --resources $CUST_SNET4 --tags Key=kubernetes.io/cluster/${eks_project},Value=shared

export RTASSOC_ID=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID --filters Name=tag:Name,Values=${eks_project}-vpc-private | jq -r '.RouteTables[].RouteTableId')
echo "RTASSOC_ID: ${RTASSOC_ID}"

aws ec2 associate-route-table --route-table-id $RTASSOC_ID --subnet-id $CUST_SNET1
aws ec2 associate-route-table --route-table-id $RTASSOC_ID --subnet-id $CUST_SNET2
aws ec2 associate-route-table --route-table-id $RTASSOC_ID --subnet-id $CUST_SNET3
aws ec2 associate-route-table --route-table-id $RTASSOC_ID --subnet-id $CUST_SNET4

kubectl describe daemonset aws-node --namespace kube-system | grep Image | cut -d "/" -f 2
kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=failure-domain.beta.kubernetes.io/zone

cat << EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: eniconfigs.crd.k8s.amazonaws.com
spec:
  scope: Cluster
  group: crd.k8s.amazonaws.com
  version: v1beta1
  names:
    plural: eniconfigs
    singular: eniconfig
    kind: ENIConfig
EOF

cat <<EOF  | kubectl apply -f -
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
 name: $AZ1
spec:
  subnet: $CUST_SNET1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
 name: $AZ2
spec:
  subnet: $CUST_SNET2
EOF

cat <<EOF | kubectl apply -f -
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
 name: $AZ3
spec:
  subnet: $CUST_SNET3
EOF

cat <<EOF | kubectl apply -f -
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
 name: $AZ4
spec:
  subnet: $CUST_SNET4
EOF

#maxPods = (number of interfaces - 1) * (max IPv4 addresses per interface - 1) + 2

kubectl -n devops-dev run -it nginx --image=nginx --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "sec" } } }'

