#!/usr/bin/env bash

# alert
#https://nws.netways.de/tutorials/2020/10/07/kubernetes-alerting-with-prometheus-alert-manager/
#https://dev.to/cosckoya/prometheus-alertmanager-with-sendgrid-and-slack-api-4f8a
#https://grafana.com/docs/grafana/latest/datasources/cloudwatch/
#https://prometheus.io/docs/instrumenting/exporters/#http

#bash /vagrant/tz-local/resource/monitoring/install.sh
cd /vagrant/tz-local/resource/monitoring

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
STACK_VERSION=16.6.0

NS=monitoring

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm uninstall prometheus -n ${NS}
k delete ns ${NS}
k create ns ${NS}
#helm inspect values prometheus-community/kube-prometheus-stack > kube-prometheus-stack-values.yaml

kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml

cp -Rf values.yaml values.yaml_bak
sed -i "s/admin_password/${admin_password}/g" values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" values.yaml_bak
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm search repo prometheus-community
helm search repo kube-state-metrics
helm upgrade --debug --install --reuse-values prometheus prometheus-community/kube-prometheus-stack \
    -n ${NS} -f values.yaml_bak \
    --version ${STACK_VERSION} \
    --set alertmanager.persistentVolume.storageClass="gp2" \
    --set server.persistentVolume.storageClass="gp2"

k patch deployment/prometheus-kube-state-metrics -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n ${NS}
k patch deployment/prometheus-kube-state-metrics -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "monitoring"}}}}}' -n ${NS}
k patch deployment/prometheus-kube-state-metrics -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n ${NS}

helm upgrade --debug --install --reuse-values alertmanager-prometheus-kube-prometheus-alertmanager prometheus-community/alertmanager \
  -n ${NS} \
  --set alertmanager.persistentVolume.storageClass="gp2" \
  --set nodeSelector.team=devops \
  --set nodeSelector.environment=monitoring

helm uninstall tz-blackbox-exporter -n ${NS}
helm upgrade --debug --install --reuse-values -n ${NS} tz-blackbox-exporter prometheus-community/prometheus-blackbox-exporter \
  --set nodeSelector.team=devops \
  --set nodeSelector.environment=${NS}

#kubectl rollout restart statefulset.apps/alertmanager-nws-prometheus-stack-kube-alertmanager

helm repo add loki https://grafana.github.io/loki/charts
helm uninstall loki -n ${NS}
helm upgrade --install --reuse-values loki grafana/loki-stack --version 2.5.1 \
  -n ${NS} \
  --set persistence.enabled=true,persistence.type=pvc,persistence.size=10Gi
k patch statefulset/loki -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n ${NS}
k patch statefulset/loki -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "monitoring"}}}}}' -n ${NS}
k patch statefulset/loki -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n ${NS}

k patch daemonset/loki-promtail -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n ${NS}
# loki datasource: http://loki.monitoring.svc.cluster.local:3100/

cp -Rf configmap.yaml configmap.yaml_bak
sed -i "s/admin_password/${admin_password}/g" configmap.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" configmap.yaml_bak
sed -i "s/eks_project/${eks_project}/g" configmap.yaml_bak
k -n ${NS} apply -f configmap.yaml_bak
#curl -X POST http://prometheus.default.${eks_project}.eks_domain/-/reload

kubectl -n ${NS} get pods | grep prometheus-grafana | awk '{print $1}' | \
  xargs kubectl -n ${NS} delete pod

k get pv | grep prometheus

# Prometheus
#k -n ${NS} port-forward svc/prometheus-kube-prometheus-prometheus 9090
#k -n ${NS} port-forward svc/prometheus-grafana 3000:80
#k -n ${NS} port-forward svc/loki 3100:3100
#POD_NAME=$(k -n ${NS} get pods --namespace prometheus -l "app=prometheus,component=alertmanager" -o jsonpath="{.items[0].metadata.name}")
#k -n ${NS} port-forward $POD_NAME 9093

# basic auth
#https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
#https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
#echo ${basic_password} | htpasswd -i -n admin > auth
#k delete secret basic-auth-grafana -n ${NS}
#k create secret generic basic-auth-grafana --from-file=auth -n ${NS}
#k get secret basic-auth-grafana -o yaml -n ${NS}
cp -Rf grafana-ingress.yaml grafana-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" grafana-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" grafana-ingress.yaml_bak
k delete -f grafana-ingress.yaml_bak -n ${NS}
k apply -f grafana-ingress.yaml_bak -n ${NS}

#echo ${basic_password} | htpasswd -i -n admin > auth
#k delete secret basic-auth-prometheus -n ${NS}
#k create secret generic basic-auth-prometheus --from-file=auth -n ${NS}
#k get secret basic-auth-prometheus -o yaml -n ${NS}
cp -Rf prometheus-ingress.yaml prometheus-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" prometheus-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" prometheus-ingress.yaml_bak
k delete -f prometheus-ingress.yaml_bak -n ${NS}
k apply -f prometheus-ingress.yaml_bak -n ${NS}

#echo ${basic_password} | htpasswd -i -n admin > auth
#k delete secret basic-auth-alertmanager -n ${NS}
#k create secret generic basic-auth-alertmanager --from-file=auth -n ${NS}
#k get secret basic-auth-alertmanager -o yaml -n ${NS}
cp -Rf alertmanager-ingress.yaml alertmanager-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" alertmanager-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" alertmanager-ingress.yaml_bak
k delete -f alertmanager-ingress.yaml_bak -n ${NS}
k apply -f alertmanager-ingress.yaml_bak -n ${NS}

rm -Rf auth
kubectl get certificate -n ${NS}
kubectl describe certificate ingress-grafana-tls -n ${NS}

kubectl get secrets --all-namespaces | grep ingress-grafana-tls
kubectl get certificates --all-namespaces | grep ingress-grafana-tls

#curl http://grafana.default.${eks_project}.eks_domain
#admin / prom-operator
grafana_pod=$(kubectl -n ${NS} get pod | grep prometheus-grafana | awk '{print $1}')
kubectl exec -it ${grafana_pod} \
  -n ${NS} -c grafana grafana-cli admin reset-admin-password ${admin_password}
kubectl get csr -o name | xargs kubectl certificate approve

kubectl exec -it ${grafana_pod} -n ${NS} \
   -c grafana grafana-cli plugins install grafana-piechart-panel

#helm repo add influxdata https://helm.influxdata.com/
#helm install influxdb influxdata/influxdb -n ${NS}
#k patch statefulset/influxdb -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n ${NS}
#k patch statefulset/influxdb -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "monitoring"}}}}}' -n ${NS}
#k patch statefulset/influxdb -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n ${NS}

kubectl patch statefulset/alertmanager-prometheus-kube-prometheus-alertmanager -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n ${NS}

cp -Rf /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak
sed -i "s/eks_project/${eks_project}/g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak
sed -i "s/eks_domain/${eks_domain}/g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak
sed -i "s/admin_password_var/${admin_password}/g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak
sed -i "s/s3_bucket_name_var/devops-grafana-${eks_project}/g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak

grafana_token_var=$(curl -X POST -H "Content-Type: application/json" -d '{"name":"admin-key", "role": "Admin"}' "http://admin:${admin_password}@grafana.default.${eks_project}.${eks_domain}/api/auth/keys" | jq -r '.key')
echo ${grafana_token_var}
sleep 5
if [[ "${grafana_token_var}" != "" ]]; then
  sed -i "s/grafana_token_var/${grafana_token_var}/g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak
fi

aws_region=$(prop 'config' 'region' ${eks_project})
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id' ${eks_project})
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key' ${eks_project})
sed -i "s/aws_region/${aws_region}/g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak
sed -i "s/aws_access_key_id/${aws_access_key_id}/g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak
sed -i "s|aws_secret_access_key|${aws_secret_access_key}|g" /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak

cat /vagrant/tz-local/resource/monitoring/backup/grafanaSettings.json_bak

exit 0

1. aws datasource setting
  Data Sources / CloudWatch: http://grafana.default.${eks_project}.eks_domain/datasources/edit/2/
  #  Assess and secret key for "grafana" user
  #  Attach existing policies directly
  #CloudWatchReadOnlyAccess
  #AmazonEC2ReadOnlyAccess

2. import charts
https://grafana.com/grafana/dashboards/707
rds: 707
loki: 12019
k8s-storage-volumes-cluster: 11454
k8s: 13770

#custom prometheus alert
#kubectl -n monitoring get prometheusrules prometheus-kube-prometheus-alertmanager.rules -o yaml > prometheus-kube-prometheus-alertmanager.rules.yaml
kubectl -n monitoring apply -f prometheus-kube-prometheus-alertmanager.rules.yaml
