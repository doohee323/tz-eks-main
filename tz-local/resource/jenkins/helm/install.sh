#!/usr/bin/env bash

cd /vagrant/tz-local/resource/jenkins/helm

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id')
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key')

helm repo add jenkins https://charts.jenkins.io
helm search repo jenkins

helm list --all-namespaces -a
k delete namespace jenkins
k create namespace jenkins
k apply -f jenkins.yaml

cp -Rf values.yaml values.yaml_bak
sed -i "s/jenkins_aws_access_key/${aws_access_key_id}/g" values.yaml_bak
sed -i "s/jenkins_aws_secret_key/${aws_secret_access_key}/g" values.yaml_bak
sed -i "s/aws_region/${AWS_REGION}/g" values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values.yaml_bak

helm delete jenkins -n jenkins
#--reuse-values
helm upgrade --debug --install jenkins jenkins/jenkins  -f values.yaml_bak -n jenkins
#k patch svc jenkins --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":31000}]' -n jenkins
#k patch svc jenkins -p '{"spec": {"ports": [{"port": 8080,"targetPort": 8080, "name": "http"}], "type": "ClusterIP"}}' -n jenkins --force

cp -Rf jenkins-ingress.yaml jenkins-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" jenkins-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" jenkins-ingress.yaml_bak
k apply -f jenkins-ingress.yaml_bak -n jenkins

echo "waiting for starting a jenkins server!"
sleep 60

k apply -f jenkins-ingress.yaml_bak -n jenkins

aws ecr create-repository \
    --repository-name devops-jenkins-${eks_project} \
    --image-tag-mutability IMMUTABLE

aws s3api create-bucket --bucket jenkins-${eks_project} --region ${AWS_REGION} --create-bucket-configuration LocationConstraint=${AWS_REGION}

aws ecr get-login-password --region ${AWS_REGION}
#--profile ${eks_project}
#
#aws ecr get-login-password --region ${AWS_REGION} \
#      | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com

ECR_REGISTRY="${aws_account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "{\"credHelpers\":{\"$ECR_REGISTRY\":\"ecr-login\"}}" > /root/.docker/config2.json
kubectl -n jenkins delete configmap docker-config
kubectl -n jenkins create configmap docker-config --from-file=/root/.docker/config2.json

kubectl -n jenkins delete secret aws-secret
kubectl -n jenkins create secret generic aws-secret \
  --from-file=/root/.aws/credentials

echo "
##[ Jenkins ]##########################################################
#  - URL: http://jenkins.default.${eks_project}.${eks_domain}
#
#  - ID: admin
#  - Password:
#    kubectl -n jenkins exec -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/chart-admin-password && echo
#######################################################################
" >> /vagrant/info
cat /vagrant/info

exit 0

#kubectl -n jenkins cp jenkins-0:/var/jenkins_home/jobs/devops-crawler/config.xml /vagrant/tz-local/resource/jenkins/jobs/config.xml

# k8s settings
https://jenkins.default.${eks_project}.${eks_domain}/manage/configureClouds/
  Kubernetes
    Jenkins URL: http://jenkins.jenkins.svc.cluster.local
  WebSocket: check
  Pod Labels
    Key: jenkins
    Value: slave

## google oauth2
client auth info > OAuth 2.0 client ID
  web application
  authorized redirection URI: https://jenkins.default.${eks_project}.${eks_domain}/securityRealm/finishLogin

https://jenkins.default.${eks_project}.${eks_domain}/manage/configureSecurity/
  Disable remember me: check
  Security Realm: Login with Google
  Client Id: 613669517643-xxx
  client_secret: GOCSPX-xxx

