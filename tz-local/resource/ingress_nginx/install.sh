#!/usr/bin/env bash

#https://box0830.tistory.com/311
#https://stackoverflow.com/questions/69403837/how-to-use-tomcat-remoteipfilter-in-spring-boot

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
APP_VERSION=4.0.13
#helm search repo nginx-ingress
helm uninstall ingress-nginx -n ${NS}

pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
allowed_management_cidr_blocks=$(terraform output allowed_management_cidr_blocks)
allowed_management_cidr_blocks=`echo ${allowed_management_cidr_blocks} | sed "s|, ]| ]|g" | tr "\n" " "`
popd
echo ${allowed_management_cidr_blocks}
cp values.yaml values.yaml_bak
allowed_management_cidr_blocks="[]"
sed -i "s|allowed_management_cidr_blocks|${allowed_management_cidr_blocks}|g" values.yaml_bak
helm upgrade --debug --install --reuse-values ingress-nginx ingress-nginx/ingress-nginx \
  -f values.yaml_bak --version ${APP_VERSION} -n ${NS}

sleep 60
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

sleep 30

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
helm uninstall cert-manager -n cert-manager
k delete -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml
kubectl get customresourcedefinition | grep cert-manager | awk '{print $1}' | xargs -I {} kubectl delete customresourcedefinition {}
k delete namespace cert-manager
k create namespace cert-manager
# Install needed CRDs
k apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml
#kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml

helm upgrade --debug --install --reuse-values \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=false \
  --version v1.6.1

sleep 30

kubectl get CustomResourceDefinition | grep cert-manager
kubectl get all -n cert-manager

k get pods --namespace cert-manager
k delete -f letsencrypt-prod.yaml
k apply -f letsencrypt-prod.yaml

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
#PROJECTS=(devops-dev devops-prod)
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

kubectl krew install ingress-nginx
kubectl ingress-nginx backends --list
kubectl ingress-nginx certs -n default --host k8s.partners.mydevops.net
kubectl ingress-nginx conf -n default --host k8s.partners.mydevops.net
kubectl ingress-nginx exec -i -n default -- ls /etc/nginx
kubectl ingress-nginx info -n default --service ingress-nginx-controller
kubectl ingress-nginx ingresses --all-namespaces
#kubectl get ingresses --all-namespaces
kubectl ingress-nginx logs -n default

exit 0

PROJECTS=($(kubectl get namespaces | awk '{print $1}' | tr '\n' ' '))
#PROJECTS=(devops-dev devops-prod)
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


exit 0

data:
  ssl-redirect: 'false'
  enable-real-ip: 'true'
  forwarded-for-header: X-Forwarded-For
  use-forwarded-headers: 'true'
  proxy-real-ip-cidr: "10.0.0.0/8"
  log-format-upstream: >-
    {"time": "$time_iso8601", "remote_addr": "$proxy_protocol_addr",
    "x_forward_for": "$http_x_forwarded_for", "request_id": "$req_id",
    "remote_user": "$remote_user", "bytes_sent": $bytes_sent, "request_time":
    $request_time, "status": $status, "vhost": "$host", "request_proto":
    "$server_protocol", "path": "$uri", "request_query": "$args",
    "request_length": $request_length, "duration": $request_time,"method":
    "$request_method", "http_referrer": "$http_referer", "http_user_agent":
    "$http_user_agent" }



#https://blog.lael.be/post/8989
#TCP/SSL 리스너가 있는 Classic Load Balancer의 경우 대상 애플리케이션과 Classic Load Balancer에서 프록시 프로토콜 지원을 활성화합니다. 로드 밸런서와 애플리케이션 모두에서 프록시 프로토콜 지원을 구성해야 합니다.

#Enable proxy protocol using the AWS CLI
#https://docs.aws.amazon.com/ko_kr/elasticloadbalancing/latest/classic/enable-proxy-protocol.html#enable-proxy-protocol-cli

aws elb describe-load-balancer-policy-types | grep ProxyProtocol -A 5 -B 5
#          "PolicyAttributeTypeDescriptions": [
#                {
#                    "Cardinality": "ONE",
#                    "AttributeName": "ProxyProtocol",
#                    "AttributeType": "Boolean"
#                }
#            ],
#            "PolicyTypeName": "ProxyProtocolPolicyType",

aws elb create-load-balancer-policy --load-balancer-name a591376a9c4be4de6be75307f38c5ca4 \
  --policy-name a591376a9c4be4de6be75307f38c5ca4-policy \
  --policy-type-name ProxyProtocolPolicyType \
  --policy-attributes AttributeName=ProxyProtocol,AttributeValue=true

aws elb set-load-balancer-policies-for-backend-server \
  --load-balancer-name a591376a9c4be4de6be75307f38c5ca4 \
  --instance-port 30218 \
  --policy-names a591376a9c4be4de6be75307f38c5ca4-policy

aws elb describe-load-balancers --load-balancer-name a591376a9c4be4de6be75307f38c5ca4  | grep a591376a9c4be4de6be75307f38c5ca4-policy -A 5 -B 5
#            "BackendServerDescriptions": [
#                {
#                    "InstancePort": 30218,
#                    "PolicyNames": [
#                        "a591376a9c4be4de6be75307f38c5ca4-policy"
#                    ]
#                }
#            ],
