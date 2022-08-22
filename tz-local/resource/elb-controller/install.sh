#https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/deploy/installation.md
#https://github.com/GSA/terraform-kubernetes-aws-load-balancer-controller/blob/main/main.tf

#bash /vagrant/tz-local/resource/elb-controller/install.sh
cd /vagrant/tz-local/resource/elb-controller

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
AWS_REGION=$(prop 'config' 'region')
eks_domain=$(prop 'project' 'domain')
eks_project=$(prop 'project' 'project')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)
NS=default

##Create IAM OIDC provider
#eksctl utils associate-iam-oidc-provider \
#    --region ${AWS_REGION} \
#    --cluster ${eks_project} \
#    --approve

curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

policy_name=AWSLoadBalancerControllerIAMPolicy-${eks_project}
policy_arn=$(aws iam list-policies | grep ${policy_name} | grep Arn | head -n 1 | awk '{print $2}' | sed "s/\"//g;s/,//g")
aws iam delete-policy --policy-arn ${policy_arn}
aws iam create-policy \
  --policy-name ${policy_name} \
  --policy-document file://iam_policy.json

eksctl delete iamserviceaccount \
  --cluster ${eks_project} \
  --namespace kube-system \
  --name aws-load-balancer-controller-${eks_project}

eksctl create iamserviceaccount \
  --cluster ${eks_project} \
  --namespace kube-system \
  --name aws-load-balancer-controller-${eks_project} \
  --attach-policy-arn arn:aws:iam::${aws_account_id}:policy/${policy_name} \
  --override-existing-serviceaccounts \
  --approve

#!!!note "Use Fargate" If you want to run it in Fargate, use Helm that does not depend on cert-manager.
helm repo add eks https://aws.github.io/eks-charts
helm repo update
kubectl delete -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm uninstall aws-load-balancer-controller -n kube-system
helm upgrade --debug --install --reuse-values aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=${eks_project} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller-${eks_project} \
  --version "1.2.6"

exit 0

##### test #####
HOSTZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == '${eks_domain}.']" | grep '"Id"'  | awk '{print $2}' | sed 's/\"//g;s/,//' | cut -d'/' -f3)
echo $HOSTZONE_ID

DEVOPS_ELB=$(kubectl get svc | grep ingress-nginx-controller | head -n 1 | awk '{print $4}')
if [[ "${DEVOPS_ELB}" == "" ]]; then
  echo "No elb! check nginx-ingress-controller with LoadBalancer type!"
  exit 1
fi
echo "DEVOPS_ELB: $DEVOPS_ELB"
# Creates route 53 records based on DEVOPS_ELB
CUR_ELB=$(aws route53 list-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} --query "ResourceRecordSets[?Name == '\\052.${NS}.${eks_project}.${eks_domain}.']" | grep 'Value' | awk '{print $2}' | sed 's/"//g')
echo "CUR_ELB: $CUR_ELB"
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
 --change-batch '{ "Comment": "'"${eks_project}"' utils", "Changes": [{"Action": "DELETE", "ResourceRecordSet": {"Name": "*.'"${NS}"'.'"${eks_project}"'.'"${eks_domain}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${CUR_ELB}"'"}]}}]}'
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
 --change-batch '{ "Comment": "'"${eks_project}"' utils", "Changes": [{"Action": "CREATE", "ResourceRecordSet": { "Name": "*.'"${NS}"'.'"${eks_project}"'.'"${eks_domain}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${DEVOPS_ELB}"'"}]}}]}'

CM_ARN=$(aws acm list-certificates --query CertificateSummaryList[].[CertificateArn,DomainName] \
  --certificate-statuses ISSUED --output text | grep "*.${eks_domain}" | cut -f1 | head -n 1)
echo "CM_ARN: $CM_ARN"

cp test2.yaml test2.yaml_bak
sed -i "s|AWS_REGION|${AWS_REGION}|g" test2.yaml_bak
sed -i "s|CM_ARN|${CM_ARN}|g" test2.yaml_bak
sed -i "s|aws_account_id|${aws_account_id}|g" test2.yaml_bak

kubectl patch ingress ingress-external-test -n default -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl patch ingress ingress-internal-test -n default -p '{"metadata":{"finalizers":[]}}' --type=merge

kubectl delete -f test2.yaml_bak
kubectl delete -f test.yaml

kubectl apply -f test.yaml
kubectl apply -f test2.yaml_bak

sleep 60

kubectl get ingress
kubectl get svc | grep ingress-test

echo "curl http://test1.${eks_domain}"
curl -v http://test1.${eks_domain}











