#!/usr/bin/env bash

#https://kubesphere.io/docs/quick-start/minimal-kubesphere-on-k8s/
#https://kubesphere.io/docs/installing-on-kubernetes/hosted-kubernetes/install-kubesphere-on-eks/#install-kubesphere-on-eks
#https://kubesphere.io/docs/multicluster-management/import-cloud-hosted-k8s/import-aws-eks/

#https://kubesphere.io/docs/faq/observability/byop/

#bash /vagrant/tz-local/resource/kubesphere/monitoring/install.sh
cd /vagrant/tz-local/resource/kubesphere/monitoring

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

function prop {
  if [[ "${3}" == "" ]]; then
    grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
  else
    grep "${3}" "/home/vagrant/.aws/${1}" -A 10 | grep "${2}" | head -n 1 | tail -n 1 | cut -d '=' -f2 | sed 's/ //g'
  fi
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
basic_password=$(prop 'project' 'basic_password')

NS=kubesphere-monitoring-system

cp -Rf grafana-configmap.yaml grafana-configmap.yaml_bak
sed -i "s/admin_password/${admin_password}/g" grafana-configmap.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" grafana-configmap.yaml_bak
sed -i "s/eks_project/${eks_project}/g" grafana-configmap.yaml_bak
k -n ${NS} apply -f grafana-configmap.yaml_bak

#kubectl -n kubesphere-monitoring-system create secret generic kube-etcd-client-certs

#kubectl edit deploy/grafana --namespace kubesphere-monitoring-system
#      securityContext:
#        runAsUser: 65534
#  =>
#      securityContext:
#        runAsUser: 472
#        fsGroup: 472

kubectl exec --namespace kubesphere-monitoring-system -c grafana -it $(kubectl get pods --namespace kubesphere-monitoring-system -l "app=grafana" -o jsonpath="{.items[0].metadata.name}") \
  -- grafana-cli admin reset-admin-password ${admin_password}

cp -Rf grafana-ingress.yaml grafana-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" grafana-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" grafana-ingress.yaml_bak
k delete -f grafana-ingress.yaml_bak -n kubesphere-monitoring-system
k apply -f grafana-ingress.yaml_bak -n kubesphere-monitoring-system

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

NS=monitoring
#k delete ns ${NS}
k create ns ${NS}

helm uninstall tz-blackbox-exporter -n ${NS}
helm upgrade --debug --install --reuse-values -n ${NS} tz-blackbox-exporter prometheus-community/prometheus-blackbox-exporter \
  --set nodeSelector.team=devops \
  --set nodeSelector.environment=prod

#kubectl rollout restart statefulset.apps/alertmanager-nws-prometheus-stack-kube-alertmanager

helm repo add loki https://grafana.github.io/loki/charts
helm uninstall loki -n ${NS}
helm upgrade --debug --install --reuse-values loki loki/loki-stack \
  -n ${NS} \
  --set persistence.enabled=true,persistence.type=pvc,persistence.size=10Gi
k patch statefulset/loki -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n ${NS}
k patch statefulset/loki -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "prod"}}}}}' -n ${NS}
k patch statefulset/loki -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n ${NS}

k patch daemonset/loki-promtail -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n ${NS}
# loki datasource: http://loki.monitoring.svc.cluster.local:3100/

cp -Rf backup/grafanaSettings.json backup/grafanaSettings.json_bak
sed -i "s/eks_project/${eks_project}/g" backup/grafanaSettings.json_bak
sed -i "s/eks_domain/${eks_domain}/g" backup/grafanaSettings.json_bak
sed -i "s/admin_password_var/${admin_password}/g" backup/grafanaSettings.json_bak
sed -i "s/s3_bucket_name_var/devops-grafana-${eks_project}/g" backup/grafanaSettings.json_bak

grafana_token_var=$(curl -X POST -H "Content-Type: application/json" -d '{"name":"admin-key", "role": "Admin"}' http://admin:${admin_password}@grafana.default.${eks_project}.${eks_domain}/api/auth/keys | jq -r '.key')
if [[ "${grafana_token_var}" != "" ]]; then
  sed -i "s/grafana_token_var/${grafana_token_var}/g" backup/grafanaSettings.json_bak
fi

aws_region=$(prop 'config' 'region' ${eks_project})
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id' ${eks_project})
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key' ${eks_project})
sed -i "s/aws_region/${aws_region}/g" backup/grafanaSettings.json_bak
sed -i "s/aws_access_key_id/${aws_access_key_id}/g" backup/grafanaSettings.json_bak
sed -i "s|aws_secret_access_key|${aws_secret_access_key}|g" backup/grafanaSettings.json_bak

#cat backup/grafanaSettings.json_bak

## Grafana ##
# Data Sources / Prometheus
# http://prometheus-operated.kubesphere-monitoring-system.svc:9090

## Loki ##
# http://loki.monitoring.svc.cluster.local:3100/