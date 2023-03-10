#!/bin/bash

# sudo bash /vagrant/scripts/eks_remove_all.sh

PROJECT_BASE='/vagrant/terraform-aws-eks/workspace/base'
cd ${PROJECT_BASE}

function cleanTfFiles() {
  rm -Rf kubeconfig_*
  rm -Rf .terraform
  rm -Rf terraform.tfstate
  rm -Rf terraform.tfstate.backup
  rm -Rf s3_bucket_id
  rm -Rf /vagrant/config_*
  rm -Rf /home/vagrant/.aws
  rm -Rf /home/vagrant/.kube
  sudo rm -Rf /root/.aws
  sudo rm -Rf /root/.kube
  rm -Rf /vagrant/terraform-aws-eks/workspace/base/lb2.tf
}

if [[ "$1" == "cleanTfFiles" ]]; then
  cleanTfFiles
fi

rm -Rf /vagrant/terraform-aws-eks/workspace/base/lb2.tf
aws logs delete-log-group --log-group-name /aws/eks/${eks_project}/cluster

export AWS_PROFILE=default
function propProject {
	grep "${1}" "/home/vagrant/.aws/project" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
export eks_project=$(propProject 'project')
export aws_account_id=$(propProject 'aws_account_id')
function propConfig {
  grep "${1}" "/home/vagrant/.aws/config" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
aws_region=$(propConfig 'region')
export AWS_DEFAULT_REGION="${aws_region}"

if [[ "${AWS_DEFAULT_REGION}" == "" || "${eks_project}" == "" ]]; then
  cleanTfFiles
  echo "AWS_DEFAULT_REGION or eks_project is null"
  exit 1
fi

sed -i "s/aws_region/${aws_region}/g" /vagrant/terraform-aws-eks/local.tf
sed -i "s/eks_project/${eks_project}/g" /vagrant/terraform-aws-eks/local.tf
sed -i "s/aws_region/${aws_region}/g" ${PROJECT_BASE}/locals.tf
sed -i "s/eks_project/${eks_project}/g" ${PROJECT_BASE}/locals.tf
sed -i "s/aws_account_id/${aws_account_id}/g" ${PROJECT_BASE}/locals.tf

for item in $(eksctl get nodegroup --cluster=${eks_project} | grep ${eks_project} | awk '{print $2}'); do
	eksctl delete nodegroup --cluster=${eks_project} --name=${item} --disable-eviction
done

for item in $(aws autoscaling describe-auto-scaling-groups --max-items 75 | grep 'AutoScalingGroupName' | grep ${eks_project} | awk '{print $2}' | sed 's/"//g'); do
	aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ${item::-1} --force-delete
done

for item in $(aws autoscaling describe-launch-configurations --max-items 75 | grep 'LaunchConfigurationName' | grep ${eks_project} | awk '{print $2}' | sed 's/"//g'); do
  aws autoscaling delete-launch-configuration --launch-configuration-name ${item::-1}
done

for item in $(aws ec2 describe-addresses --filters "Name=tag:Name,Values=${eks_project}*" | grep '"PublicIp"' | awk '{print $2}' | sed 's/"//g'); do
  aws ec2 release-address --public-ip ${item::-1}
done

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${eks_project}-vpc" --out=text | awk '{print $8}' | head -n 1)
echo "VPC_ID: ${VPC_ID}"
for elb_arn in $(aws elbv2 describe-load-balancers --output text | grep ${VPC_ID} | awk '{print $6}'); do
    echo "elb deleting =======> ${elb_arn}"
    aws elbv2 delete-load-balancer --load-balancer-arn ${elb_arn}
done

for item in $(aws elb describe-load-balancers --output text | grep ${VPC_ID} | awk '{print $6}'); do
  if [[ "$(aws elb describe-tags --load-balancer-name ${item} --output=text | grep ${eks_project})" != "" ]]; then
    aws elb delete-load-balancer --load-balancer-name ${item}
  fi
done

aws iam delete-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/AmazonEKS_EBS_CSI_Driver_Policy-${eks_project}
aws iam delete-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/AWSLoadBalancerControllerIAMPolicy-${eks_project}
aws iam delete-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/${eks_project}-ecr-policy
aws iam delete-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/${eks_project}-es-s3-policy

for role in $(aws iam list-roles --out=text | grep ${eks_project} | awk '{print $7}'); do
  for policy in $(aws iam list-role-policies --role-name ${role} --out=text | awk '{print $2}'); do
    aws iam delete-role-policy --role-name ${role} --policy-name ${policy}
  done
  aws iam delete-role --role-name ${role}
done

for allocation_id in $(aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]' \
      | grep ${eks_project} -B 7 | grep AllocationId | awk '{print $2}' | sed "s/\"//g;s/,//g"); do
  aws ec2 release-address --allocation-id ${allocation_id}
done

ECR_REPO=$(aws ecr describe-repositories --out=text | grep ${eks_project} | awk '{print $6}')
S3_REPO=$(aws s3api list-buckets --query "Buckets[].Name" | grep ${eks_project})

if [[ "$(aws eks describe-cluster --name ${eks_project} | grep ${eks_project})" != "" ]]; then
  #terraform init
  terraform destroy -auto-approve
  if [[ $? != 0 ]]; then
    sleep 30
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${eks_project}-vpc" --out=text | awk '{print $8}')
    echo "terraform destroy failed, try to delete vpc ${VPC_ID} again."
    aws ec2 delete-vpc --vpc-id ${VPC_ID}
    if [[ $? != 0 ]]; then
      VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${eks_project}-vpc" --out=text | awk '{print $8}')
      echo "terraform destroy failed, try to delete vpc ${VPC_ID} again."
      aws ec2 delete-vpc --vpc-id ${VPC_ID}
      if [[ $? != 0 ]]; then
        echo "failed to delete vpc."
        exit 1
      fi
    fi
  fi
fi

for item in $(eksctl get nodegroup --cluster=${eks_project} | grep ${eks_project} | awk '{print $2}'); do
	eksctl delete nodegroup --cluster=${eks_project} --name=${item} --disable-eviction
done

cleanTfFiles

git checkout /vagrant/terraform-aws-eks/local.tf
git checkout ${PROJECT_BASE}/locals.tf
git checkout ${PROJECT_BASE}/variables.tf

echo "
##[ Summary ]##########################################################
echo "You might need to delete these resources."
echo "VPC: ${eks_project}-vpc"
echo "ECR: ${ECR_REPO}"
echo "S3 bucket: ${S3_REPO} jenkins-${eks_project}"
#######################################################################
" >> /vagrant/info
cat /vagrant/info

exit 0

#- k8s-master-role in IAM Roles
#aws iam remove-role-from-instance-profile --instance-profile-name k8s-master-role --role-name k8s-master-role
#aws iam delete-instance-profile --instance-profile-name k8s-master-role
#aws iam delete-role --role-name k8s-master-role
#policy_name=`aws iam list-role-policies --role-name k8s-master-role --output=text | awk '{print $2}'`
#if [[ "${policy_name}" != "" ]]]; then
#    aws iam delete-role-policy --role-name k8s-master-role --policy-name ${policy_name}
#fi


kubectl get namespace consul -o json > consul.json
kubectl replace --raw "/api/v1/namespaces/consul/finalize" -f ./consul.json
kubectl delete namespace consul
kubectl get namespace

#kubectl get apiservice|grep False
#kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get -n consul

In one terminal:
  kubectl proxy
In another terminal:
  NS=kubesphere-monitoring-system

#  helm uninstall consul -n consul
  kubectl delete namespace ${NS}
  kubectl get ns ${NS} -o json | \
  jq '.spec.finalizers=[]' | \
  curl -X PUT http://localhost:8001/api/v1/namespaces/${NS}/finalize -H "Content-Type: application/json" --data @-

  kubectl patch ns ${NS} -p '{"metadata":{"finalizers":null}}';
  kubectl delete ns ${NS};


NS=kubesphere-alerting-system
NS=kubesphere-controls-system
NS=kubesphere-devops-system
NS=kubesphere-devops-worker
NS=kubesphere-logging-system
NS=kubesphere-monitoring-system
NS=kubesphere-monitoring-federated
NS=openpitrix-system
NS=kubesphere-system

for ns in kubesphere-alerting-system kubesphere-controls-system kubesphere-devops-system kubesphere-devops-worker kubesphere-logging-system kubesphere-monitoring-system kubesphere-monitoring-federated openpitrix-system kubesphere-system
do
  echo kubectl delete ns $ns
  kubectl delete ns $ns
#   2>/dev/null
done

#kubectl delete namespace kubesphere-alerting-system kubesphere-controls-system kubesphere-devops-system kubesphere-devops-worker kubesphere-logging-system kubesphere-monitoring-system kubesphere-monitoring-federated openpitrix-system kubesphere-system

#kubectl delete pod/prometheus-k8s-0 -n kubesphere-monitoring-system --grace-period=0 --force
#kubectl delete pod/prometheus-k8s-1 -n kubesphere-monitoring-system --grace-period=0 --force
#kubectl delete pod/elasticsearch-logging-data-0 -n kubesphere-logging-system --grace-period=0 --force

kubectl delete pod/cluster-autoscaler-aws-cluster-autoscaler-6774fccbbd-8kdmb -n kube-system --grace-period=0 --force
kubectl delete pod/ebs-csi-node-tx2j8 -n kube-system --grace-period=0 --force

kubectl delete customresourcedefinition/challenges.acme.cert-manager.io --grace-period=0 --force
#terraform force-unlock 1a52103b-39b1-8851-0ddf-57713d7f619c

kubectl get Challenges --all-namespaces

kubectl delete Challenges nginx-dns01-tls-fqhjd-1322534090-702053642 --grace-period=0 --force

kubectl delete ServiceDefaults/tz-consul-service -n consul --grace-period=0 --force
postgres
devops-demo
devops-demo-public
devops-demo-front
kubectl delete ProxyDefaults/global -n consul --grace-period=0 --force
kubectl delete Mesh/mesh -n consul --grace-period=0 --force


