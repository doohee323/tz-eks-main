#!/usr/bin/env bash

#https://box0830.tistory.com/311
#bash /vagrant/tz-local/resource/ingress_nginx/install.sh

cd /vagrant/tz-local/resource/ingress_nginx

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

#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.46.0/deploy/static/provider/aws/deploy.yaml
#kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.46.0/deploy/static/provider/aws/deploy.yaml

#kubectl delete ns ${NS}
kubectl create ns ${NS}
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
APP_VERSION=3.35.0
#helm search repo nginx-ingress
helm uninstall ingress-nginx -n ${NS}
helm upgrade --debug --install --reuse-values ingress-nginx ingress-nginx/ingress-nginx --version ${APP_VERSION} -n ${NS}

sleep 20
DEVOPS_ELB=$(kubectl get svc | grep ingress-nginx-controller | grep LoadBalancer | head -n 1 | awk '{print $4}')
if [[ "${DEVOPS_ELB}" == "" ]]; then
  echo "No elb! check nginx-ingress-controller with LoadBalancer type!"
  exit 1
fi
sleep 20
echo "DEVOPS_ELB: $DEVOPS_ELB"
# Creates route 53 records based on DEVOPS_ELB
CUR_ELB=$(aws route53 list-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} --query "ResourceRecordSets[?Name == '\\052.${NS}.${eks_project}.${eks_domain}.']" | grep 'Value' | awk '{print $2}' | sed 's/"//g')
echo "CUR_ELB: $CUR_ELB"
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
 --change-batch '{ "Comment": "'"${eks_project}"' utils", "Changes": [{"Action": "DELETE", "ResourceRecordSet": {"Name": "*.'"${NS}"'.'"${eks_project}"'.'"${eks_domain}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${CUR_ELB}"'"}]}}]}'
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
 --change-batch '{ "Comment": "'"${eks_project}"' utils", "Changes": [{"Action": "CREATE", "ResourceRecordSet": { "Name": "*.'"${NS}"'.'"${eks_project}"'.'"${eks_domain}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${DEVOPS_ELB}"'"}]}}]}'

#k delete deployment nginx
#k create deployment nginx --image=nginx
#k delete svc/nginx
##k port-forward deployment/nginx 80
##k expose deployment/nginx --port 80 --type LoadBalancer
#k expose deployment/nginx --port 80

cp -Rf nginx-ingress.yaml nginx-ingress.yaml_bak
sed -i "s|NS|${NS}|g" nginx-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" nginx-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" nginx-ingress.yaml_bak
k delete -f nginx-ingress.yaml_bak
k delete ingress $(k get ingress nginx-test-tls)
k delete svc nginx
k apply -f nginx-ingress.yaml_bak
echo curl http://test.${NS}.${eks_project}.${eks_domain}
sleep 30
curl -v http://test.${NS}.${eks_project}.${eks_domain}
k delete -f nginx-ingress.yaml_bak

#### https ####
helm repo add jetstack https://charts.jetstack.io
helm repo update

## Install using helm v3+
helm uninstall cert-manager --namespace cert-manager
k delete namespace cert-manager
k create namespace cert-manager
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=false \
  --version v0.15.2
# Install needed CRDs
k apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.crds.yaml
#kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.crds.yaml

#helm install \
#  cert-manager jetstack/cert-manager \
#  --namespace cert-manager \
#  --create-namespace \
#  --set featureGates="ExperimentalCertificateSigningRequestControllers=true" \
#  # --set installCRDs=true

k get pods --namespace cert-manager
k delete -f letsencrypt-prod.yaml
k apply -f letsencrypt-prod.yaml

#k delete deployment nginx
#k create deployment nginx --image=nginx
#k delete svc/nginx
##k port-forward deployment/nginx 80
##k expose deployment/nginx --port 80 --type LoadBalancer
#k expose deployment/nginx --port 80

sleep 20

cp -Rf nginx-ingress-https.yaml nginx-ingress-https.yaml_bak
sed -i "s/NS/${NS}/g" nginx-ingress-https.yaml_bak
sed -i "s/eks_project/${eks_project}/g" nginx-ingress-https.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" nginx-ingress-https.yaml_bak
k delete -f nginx-ingress-https.yaml_bak -n ${NS}
k delete ingress nginx-test-tls -n ${NS}
k apply -f nginx-ingress-https.yaml_bak -n ${NS}
kubectl get csr -o name | xargs kubectl certificate approve
echo curl http://test.${NS}.${eks_project}.${eks_domain}
sleep 10
curl -v http://test.${NS}.${eks_project}.${eks_domain}
echo curl https://test.${NS}.${eks_project}.${eks_domain}
curl -v https://test.${NS}.${eks_project}.${eks_domain}

kubectl get certificate -n ${NS}
kubectl describe certificate nginx-test-tls -n ${NS}

kubectl get secrets --all-namespaces | grep nginx-test-tls
kubectl get certificates --all-namespaces | grep nginx-test-tls

PROJECTS=($(kubectl get namespaces | awk '{print $1}' | tr '\n' ' '))
#PROJECTS=(argocd monitoring devops devops-dev)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    echo "====================="
    echo ${item}
#    echo bash /vagrant/tz-local/resource/ingress_nginx/update.sh ${item} ${eks_project} ${eks_domain}
    bash /vagrant/tz-local/resource/ingress_nginx/update.sh ${item} ${eks_project} ${eks_domain}
  fi
done

kubectl get certificate -n ${NS}
kubectl describe certificate nginx-test-tls -n ${NS}

kubectl get secrets --all-namespaces | grep nginx-test-tls
kubectl get certificates --all-namespaces | grep nginx-test-tls

kubectl get csr
kubectl get csr -o name | xargs kubectl certificate approve

kubectl get certificate --all-namespaces
kubectl cert-manager renew ingress-vault-tls -n vault

exit 0

PROJECTS=($(kubectl get namespaces | awk '{print $1}' | tr '\n' ' '))
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    echo "====================="
    echo ${item}
    kubectl cert-manager renew --namespace=${item} --all
  fi
done

kubectl cert-manager create certificaterequest my-cr --from-certificate-file my-certificate.yaml --fetch-certificate --timeout 20m
kubectl cert-manager status certificate ingress-vault-tls-3746172421 -n vault
kubectl get CertificateRequest ingress-vault-tls-3746172421 -n vault

kubectl get certificaterequest --all-namespaces

kubectl cert-manager completion
kubectl cert-manager renew ingress-vault-tls -n vault

kubectl get certificaterequest --all-namespaces
kubectl get certificates --all-namespaces

kubectl delete certificates ingress-consul-tls -n consul
kubectl delete certificaterequest ingress-consul-tls-4229033796 -n consul


