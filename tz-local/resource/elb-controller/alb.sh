#!/bin/bash

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_domain=$(prop 'project' 'domain')

NS="devops-dev"
SERVICE="devops-demo"
INGRESS_NAME="ingress-external-devops-demo"

alias k="kubectl -n ${NS} --kubeconfig ~/.kube/config"

HOSTZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == '${eks_domain}.']" | grep '"Id"'  | awk '{print $2}' | sed 's/\"//g;s/,//' | cut -d'/' -f3)
echo $HOSTZONE_ID

DEVOPS_ELB=$(k get ingress | grep ${INGRESS_NAME} | head -n 1 | awk '{print $4}')
echo $DEVOPS_ELB
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
 --change-batch '{ "Comment": "'"${SERVICE}"'", "Changes": [{"Action": "CREATE", "ResourceRecordSet": { "Name": "'"${SERVICE}"'.'"${eks_domain}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${DEVOPS_ELB}"'"}]}}]}'

exit

CM_ARN=$(aws acm list-certificates --query CertificateSummaryList[].[CertificateArn,DomainName] \
  --certificate-statuses ISSUED --output text | grep "${eks_domain}" | cut -f1 | head -n 1)
echo "[for k8s.yaml]################################ "
echo ${CM_ARN}
echo "############################################## "

