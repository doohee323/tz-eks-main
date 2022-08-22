#!/usr/bin/env bash

# https://docs.datadoghq.com/agent/kubernetes/?tab=helm
#https://github.com/JungYoungseok/K8S_Webinar_202006/blob/master/datadog-agent-all-enabled.yaml

#bash /vagrant/tz-local/resource/datadog/install.sh
cd /vagrant/tz-local/resource/datadog

#set -x
shopt -s expand_aliases

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
basic_password=$(prop 'project' 'basic_password')
DD_API_KEY=$(prop 'project' 'datadog_apikey')
DD_APP_KEY=$(prop 'project' 'datadog_appkey')

helm repo add datadog https://helm.datadoghq.com
helm repo update

#https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml
cp values.yaml values.yaml_bak
sed -i "s/datadog_apikey/${DD_API_KEY}/g" values.yaml_bak
sed -i "s/datadog_appkey/${DD_APP_KEY}/g" values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values.yaml_bak
helm uninstall datadog-${eks_project} -n devops
helm upgrade --debug --install --reuse-values datadog-${eks_project} \
  -f values.yaml_bak \
  -n devops \
  datadog/datadog

#  --set datadog.site='us3.datadoghq.com' \

cp k8s.yaml k8s.yaml_bak
sed -i "s/CLUSTER_NAME/${eks_project}/g" k8s.yaml_bak
sed -i "s/DOMAIN_NAME/${eks_domain}/g" k8s.yaml_bak
kubectl apply -f k8s.yaml_bak -n devops

exit 0

curl -X GET "https://api.datadoghq.com/api/v2/api_keys" \
-H "Content-Type: application/json" \
-H "DD-API-KEY: ${DD_API_KEY}" \
-H "DD-APPLICATION-KEY: ${DD_APP_KEY}"

