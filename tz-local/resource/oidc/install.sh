#!/usr/bin/env bash

#https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
#https://veluxer62.github.io/study/kubernetes-study-05/

cd /vagrant/tz-local/resource/oidc

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
AWS_REGION=$(prop 'config' 'region')
eks_project=$(prop 'project' 'project')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

# IAM OIDC 공급자 생성
issuerUrl=$(aws eks describe-cluster --name ${eks_project} --query "cluster.identity.oidc.issuer" --output text)
echo "issuerUrl: ${issuerUrl}"
issuerUrl=$(aws iam list-open-id-connect-providers | grep ${issuerUrl##*/})
issuerUrl=${issuerUrl##*/}
OIDC_URL=${issuerUrl:0:-1}
echo "OIDC_URL: ${OIDC_URL}"

eksctl utils associate-iam-oidc-provider --cluster ${eks_project} --approve

# IAM 정책 생성
aws iam delete-policy --policy-arn "arn:aws:iam::${aws_account_id}:policy/oidc-policy"

cp -Rf policy.json policy.json_bak
sed -i "s/eks_project/${eks_project}/g" policy.json_bak
tmp=$(aws iam create-policy --policy-name oidc-policy --policy-document file://policy.json_bak)
IAM_POLICY_ARN=$(echo ${tmp} | jq '.Policy.Arn')
echo "IAM_POLICY_ARN: ${IAM_POLICY_ARN}"

# 서비스 계정에 대한 IAM 역할 생성
eksctl delete iamserviceaccount \
    --name tz-oidc-service-account \
    --namespace default \
    --cluster ${eks_project}

eksctl create iamserviceaccount \
    --name tz-oidc-service-account \
    --namespace default \
    --cluster ${eks_project} \
    --attach-policy-arn ${IAM_POLICY_ARN} \
    --approve \
    --override-existing-serviceaccounts

# IAM 역할을 서비스 계정에 연결
kubectl annotate serviceaccount -n default tz-oidc-service-account \
  eks.amazonaws.com/role-arn=arn:aws:iam::aws_account_id:role/${eks_project}-oidc \
  --overwrite

#kubectl delete pods -n kube-system -l k8s-app=aws-node
kubectl get pods -n kube-system -l k8s-app=aws-node

kubectl run -n default awscli -it --rm --image=amazon/aws-cli \
  --serviceaccount='tz-oidc-service-account' --command -- sh

kubectl exec -n kube-system \
  $(kubectl get pods -n kube-system -l k8s-app=aws-node | grep aws-node | head -n 1 | awk '{print $1}') \
  -- /usr/bin/env | grep KUBERNETES_SERVICE_HOST
