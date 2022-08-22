#!/usr/bin/env bash

#* https://medium.com/@warolv/building-the-ci-cd-of-the-future-nginx-ingress-cert-manager-945f3dc6b12e
#bash /vagrant/tz-local/resource/nginx_ingress/install.sh

cd /vagrant/tz-local/resource/nginx_ingress

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}

NS=$1
if [[ "${NS}" == "" ]]; then
  NS=default
fi
eks_project=$2
if [[ "${eks_project}" == "" ]]; then
  eks_project=$(prop 'project' 'project')
fi
eks_domain=$3
if [[ "${eks_domain}" == "" ]]; then
  eks_domain=$(prop 'project' 'domain')
fi
HOSTZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == '${eks_domain}.']" | grep '"Id"'  | awk '{print $2}' | sed 's/\"//g;s/,//' | cut -d'/' -f3)
echo $HOSTZONE_ID

#set -x
shopt -s expand_aliases
alias k="kubectl -n ${NS} --kubeconfig ~/.kube/config"

#kubectl delete ns ${NS}
kubectl create ns ${NS}
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
#helm search repo nginx-ingress
helm uninstall nginx-ingress -n ${NS}
sleep 30
helm upgrade --debug --install --reuse-values nginx-ingress nginx-stable/nginx-ingress \
  -f values.yaml -n ${NS}
sleep 30
DEVOPS_ELB=$(kubectl get svc | grep nginx-ingress-controller | head -n 1 | awk '{print $4}')
if [[ "${DEVOPS_ELB}" == "" ]]; then
  echo "No elb! check nginx-ingress-controller with LoadBalancer type!"
  exit 1
fi
echo "DEVOPS_ELB: $DEVOPS_ELB"
# Creates route 53 records based on DEVOPS_ELB
echo aws route53 list-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} --query "ResourceRecordSets[?Name == '\\052.${NS}.${eks_project}.${eks_domain}.']" | grep 'Value' | awk '{print $2}' | sed 's/"//g'
CUR_ELB=$(aws route53 list-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} --query "ResourceRecordSets[?Name == '\\052.${NS}.${eks_project}.${eks_domain}.']" | grep 'Value' | awk '{print $2}' | sed 's/"//g')
echo "CUR_ELB: $CUR_ELB"
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
 --change-batch '{ "Comment": "'"${eks_project}"' utils", "Changes": [{"Action": "DELETE", "ResourceRecordSet": {"Name": "*.'"${NS}"'.'"${eks_project}"'.'"${eks_domain}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${CUR_ELB}"'"}]}}]}'
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
 --change-batch '{ "Comment": "'"${eks_project}"' utils", "Changes": [{"Action": "CREATE", "ResourceRecordSet": { "Name": "*.'"${NS}"'.'"${eks_project}"'.'"${eks_domain}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${DEVOPS_ELB}"'"}]}}]}'

k delete deployment nginx
k create deployment nginx --image=nginx
k delete svc/nginx
#k port-forward deployment/nginx 80
#k expose deployment/nginx --port 80 --type LoadBalancer
k expose deployment/nginx --port 80

cp -Rf nginx-ingress.yaml nginx-ingress.yaml_bak
sed -i "s|NS|${NS}|g" nginx-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" nginx-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" nginx-ingress.yaml_bak
k delete -f nginx-ingress.yaml_bak
#k delete ingress nginx-test-tls
k create -f nginx-ingress.yaml_bak
kubectl get csr -o name | xargs kubectl certificate approve
sleep 10
echo curl http://test.${NS}.${eks_project}.${eks_domain}
curl -v http://test.${NS}.${eks_project}.${eks_domain}
k delete -f nginx-ingress.yaml_bak

#k run -it busybox --image=busybox --restart=Never --rm -- sh
#k run -it busybox --image=busybox --restart=Never --rm -- sh
#k run -it busybox --image=busybox --restart=Never --rm -- nslookup test.default.svc.cluster.local

###Create cert-manager namespace
#k create namespace cert-manager
#helm repo add jetstack https://charts.jetstack.io
#helm repo update
#
## Install needed CRDs
#k apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.14/deploy/manifests/00-crds.yaml
#
## Install using helm v3+
#helm install \
#  cert-manager jetstack/cert-manager \
#  --namespace cert-manager \
#  --version v0.14
#
#k get pods --namespace cert-manager
