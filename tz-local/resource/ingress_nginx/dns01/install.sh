#!/usr/bin/env bash

#https://box0830.tistory.com/311
#https://stackoverflow.com/questions/69403837/how-to-use-tomcat-remoteipfilter-in-spring-boot

source /root/.bashrc
#bash /vagrant/tz-local/resource/ingress_nginx/dns01/install.sh
cd /vagrant/tz-local/resource/ingress_nginx/dns01

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
AWS_REGION=$(prop 'config' 'region')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

VERSION=v1.6.1
#VERSION=v1.8.0

#set -x
shopt -s expand_aliases
alias k="kubectl -n ${NS} --kubeconfig ~/.kube/config"

aws iam delete-policy --policy-arn "arn:aws:iam::${aws_account_id}:policy/${eks_project}-AmazonRoute53Domains-cert-manager"
aws iam create-policy \
  --policy-name ${eks_project}-AmazonRoute53Domains-cert-manager \
  --description "Policy required by cert-manager to be able to modify Route 53 when generating wildcard certificates using Lets Encrypt" \
  --policy-document file://route_53_change_policy.json

POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName==\`${eks_project}-AmazonRoute53Domains-cert-manager\`].{ARN:Arn}" --output text)
echo "POLICY_ARN: ${POLICY_ARN}"
aws iam create-user --user-name ${eks_project}-eks-cert-manager-route53
aws iam attach-user-policy --user-name "${eks_project}-eks-cert-manager-route53" --policy-arn $POLICY_ARN
if [ ! -f "$HOME/.aws/${eks_project}-eks-cert-manager-route53" ]; then
  aws iam create-access-key --user-name ${eks_project}-eks-cert-manager-route53 > $HOME/.aws/${eks_project}-eks-cert-manager-route53
fi
export CERT_MANAGER_AWS_ACCESS_KEY_ID=$(awk -F\" "/AccessKeyId/ { print \$4 }" $HOME/.aws/${eks_project}-eks-cert-manager-route53)
export CERT_MANAGER_AWS_SECRET_ACCESS_KEY=$(awk -F\" "/SecretAccessKey/ { print \$4 }" $HOME/.aws/${eks_project}-eks-cert-manager-route53)
echo "CERT_MANAGER_AWS_ACCESS_KEY_ID: ${CERT_MANAGER_AWS_ACCESS_KEY_ID}"
echo "CERT_MANAGER_AWS_SECRET_ACCESS_KEY: ${CERT_MANAGER_AWS_SECRET_ACCESS_KEY}"

#### https ####
helm repo add jetstack https://charts.jetstack.io
helm repo update

## Install using helm v3+
helm uninstall cert-manager -n cert-manager
kubectl patch crd challenges.certmanager.k8s.io -p '{"metadata":{"finalizers": []}}' --type=merge
kubectl patch crd challenges.acme.cert-manager.io -p '{"metadata":{"finalizers": []}}' --type=merge
kubectl patch crd servicedefaults.consul.hashicorp.com -p '{"metadata":{"finalizers": []}}' --type=merge
k delete -f https://github.com/jetstack/cert-manager/releases/download/${VERSION}/cert-manager.crds.yaml
kubectl get customresourcedefinition | grep cert-manager | awk '{print $1}' | xargs -I {} kubectl delete customresourcedefinition {}
#kubectl get customresourcedefinition | grep consul.hashicorp.com | awk '{print $1}' | xargs -I {} kubectl delete customresourcedefinition {}
k delete namespace cert-manager
k create namespace cert-manager

pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
export cert_manager_irsa_role_arn=$(terraform output | grep 'cert_manager_irsa_role_arn' |  cut -d '=' -f2 | sed 's/ //g')
echo "cert_manager_irsa_role_arn: ${cert_manager_irsa_role_arn}"
cluster_iam_role=$(terraform output | grep cluster_iam_role_arn | awk '{print $3}' | tr "/" "\n" | tail -n 1 | sed 's/"//g')
echo cluster_iam_role: ${cluster_iam_role}
popd

# Install needed CRDs
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/${VERSION}/cert-manager.crds.yaml
#kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/${VERSION}/cert-manager.crds.yaml

cp -Rf cert-manager-values.yml cert-manager-values.yml_bak
sed -i "s|aws_account_id|${aws_account_id}|g" cert-manager-values.yml_bak
sed -i "s|cluster_iam_role|${cluster_iam_role}|g" cert-manager-values.yml_bak
sed -i "s|cert_manager_irsa_role_arn|${cert_manager_irsa_role_arn}|g" cert-manager-values.yml_bak
# --reuse-values
helm upgrade --debug --install --reuse-values \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values "cert-manager-values.yml_bak" \
  --set installCRDs=false \
  --set 'extraArgs={--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=8.8.8.8:53\,1.1.1.1:53}' \
  --version ${VERSION}

sleep 30

kubectl get crd | grep cert-manager
kubectl get all -n cert-manager

helm repo add --force-update appscode https://charts.appscode.com/stable/
helm upgrade --install -n kubed kubed appscode/kubed \
  --create-namespace \
  --set imagePullPolicy=Always \
  --set config.clusterName=${eks_domain} \
  --version v0.12.0

export CERT_MANAGER_AWS_SECRET_ACCESS_KEY_BASE64=$(echo -n "$CERT_MANAGER_AWS_SECRET_ACCESS_KEY" | base64)
echo ${CERT_MANAGER_AWS_SECRET_ACCESS_KEY_BASE64}

cp letsencrypt-prod.yaml letsencrypt-prod.yaml_bak
sed -i "s|your_email|devops@tz.gg|g" letsencrypt-prod.yaml_bak
sed -i "s|eks_domain|${eks_domain}|g" letsencrypt-prod.yaml_bak
sed -i "s|eks_project|${eks_project}|g" letsencrypt-prod.yaml_bak
sed -i "s|AWS_REGION|${AWS_REGION}|g" letsencrypt-prod.yaml_bak
sed -i "s|HOSTZONE_ID|${HOSTZONE_ID}|g" letsencrypt-prod.yaml_bak
sed -i "s|CERT_MANAGER_AWS_ACCESS_KEY_ID|${CERT_MANAGER_AWS_ACCESS_KEY_ID}|g" letsencrypt-prod.yaml_bak
sed -i "s|CERT_MANAGER_AWS_SECRET_ACCESS_KEY_BASE64|${CERT_MANAGER_AWS_SECRET_ACCESS_KEY_BASE64}|g" letsencrypt-prod.yaml_bak
sed -i "s|cluster_iam_role|${cluster_iam_role}|g" letsencrypt-prod.yaml_bak
sed -i "s|cert_manager_irsa_role_arn|${cert_manager_irsa_role_arn}|g" letsencrypt-prod.yaml_bak
kubectl delete -f letsencrypt-prod.yaml_bak -n cert-manager
kubectl apply -f letsencrypt-prod.yaml_bak -n cert-manager
kubectl describe clusterissuer letsencrypt-prod
kubectl describe certificate ingress-cert-prod -n cert-manager
#kubectl get apiservice cert-manager.io

# cert-manager-clusterissuers Error initializing issuer: context deadline exceeded
#https://github.com/cert-manager/cert-manager/issues/2319
#kubectl edit deployment cert-manager -n cert-manager
#      dnsPolicy: ClusterFirst
#=>
#      dnsPolicy: "None"
#      dnsConfig:
#        nameservers:
#          - 8.8.8.8
#          - 8.8.4.4

kubectl wait -n cert-manager --for=condition=Ready --timeout=20m certificate "ingress-cert-prod"

cp -Rf nginx-ingress-prod.yaml nginx-ingress-prod.yaml_bak
sed -i "s/NS/${NS}/g" nginx-ingress-prod.yaml_bak
sed -i "s/eks_project/${eks_project}/g" nginx-ingress-prod.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" nginx-ingress-prod.yaml_bak
k delete -f nginx-ingress-prod.yaml_bak -n ${NS}
k delete ingress nginx-test-tls -n ${NS}
k apply -f nginx-ingress-prod.yaml_bak -n ${NS}
kubectl get csr -o name | xargs kubectl certificate approve
curl -v http://test.${NS}.${eks_project}.${eks_domain}
echo curl http://test.${NS}.${eks_project}.${eks_domain}
sleep 10
curl -v https://test.${NS}.${eks_project}.${eks_domain}
echo curl https://test.${NS}.${eks_project}.${eks_domain}

#openssl s_client -connect test.${NS}.${eks_project}.${eks_domain}:443 -prexit*


