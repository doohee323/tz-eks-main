#!/usr/bin/env bash

source /root/.bashrc
#bash /vagrant/tz-local/resource/persistent-storage/install.sh
cd /vagrant/tz-local/resource/persistent-storage

AWS_REGION=$(prop 'config' 'region')
eks_domain=$(prop 'project' 'domain')
eks_project=$(prop 'project' 'project')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)
export AWS_ACCESS_KEY_ID=$(prop 'credentials' 'aws_access_key_id')
export AWS_SECRET_ACCESS_KEY=$(prop 'credentials' 'aws_secret_access_key')

aws iam delete-policy --policy-arn "arn:aws:iam::${aws_account_id}:policy/AmazonEKS_EBS_CSI_Driver_Policy-${eks_project}"
aws iam create-policy \
    --policy-name AmazonEKS_EBS_CSI_Driver_Policy-${eks_project} \
    --policy-document file://example-iam-policy.json

eksctl delete iamserviceaccount --name ebs-csi-controller-sa --cluster ${eks_project}
eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster ${eks_project} \
    --attach-policy-arn arn:aws:iam::${aws_account_id}:policy/AmazonEKS_EBS_CSI_Driver_Policy-${eks_project} \
    --approve \
    --override-existing-serviceaccounts

aws cloudformation describe-stacks \
    --stack-name eksctl-${eks_project}-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa \
    --query='Stacks[].Outputs[?OutputKey==`Role1`].OutputValue' \
    --output text

kubectl -n kube-system delete secret aws-secret
kubectl create secret generic aws-secret \
    --namespace kube-system \
    --from-literal "key_id=${AWS_ACCESS_KEY_ID}" \
    --from-literal "access_key=${AWS_SECRET_ACCESS_KEY}"

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.12"
kubectl delete -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.12"

helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

helm uninstall aws-ebs-csi-driver --namespace kube-system
helm upgrade -install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set enableVolumeResizing=true \
  --set enableVolumeSnapshot=true \
  --set serviceAccount.controller.create=false \
  --set serviceAccount.controller.name=ebs-csi-controller-sa

exit 0
