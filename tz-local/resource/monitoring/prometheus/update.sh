#!/usr/bin/env bash

# alert
#https://nws.netways.de/tutorials/2020/10/07/kubernetes-alerting-with-prometheus-alert-manager/
#https://dev.to/cosckoya/prometheus-alertmanager-with-sendgrid-and-slack-api-4f8a
#https://grafana.com/docs/grafana/latest/datasources/cloudwatch/
#https://prometheus.io/docs/instrumenting/exporters/#http

#bash /vagrant/tz-local/resource/monitoring/prometheus/update.sh

cd /vagrant/tz-local/resource/monitoring/prometheus

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
STACK_VERSION=16.6.0
NS=monitoring

kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml && \
kubectl -n ${NS} apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.45.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml

kubectl -n ${NS} delete -f alertmanager.rules.yaml
kubectl -n ${NS} apply -f alertmanager.rules.yaml
kubectl -n ${NS} get prometheusrules

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
#helm history prometheus -n ${NS}
#helm rollback prometheus 17 -n ${NS} --force
#helm uninstall prometheus -n ${NS}
cp prometheus-values.yaml prometheus-values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" prometheus-values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" prometheus-values.yaml_bak
sed -i "s/admin_password/${admin_password}/g" prometheus-values.yaml_bak
helm upgrade --debug --install --reuse-values prometheus prometheus-community/kube-prometheus-stack \
    -n ${NS} -f prometheus-values.yaml_bak \
    --version ${STACK_VERSION} \
    --set alertmanager.persistentVolume.storageClass="gp2" \
    --set server.persistentVolume.storageClass="gp2"

cp alertmanager.values.yaml alertmanager.values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" alertmanager.values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" alertmanager.values.yaml_bak
sed -i "s/admin_password/${admin_password}/g" alertmanager.values.yaml_bak
alertmanager=$(cat alertmanager.values.yaml_bak | base64 -w0)
cp alertmanager-secret-k8s.yaml alertmanager-secret-k8s.yaml_bak
sed -i "s/ALERTMANAGER_ENCODE/${alertmanager}/g" alertmanager-secret-k8s.yaml_bak
kubectl -n ${NS} apply -f alertmanager-secret-k8s.yaml_bak
kubectl rollout restart statefulset.apps/alertmanager-prometheus-kube-prometheus-alertmanager -n ${NS}

#cp elasticsearch-exporter-values.yaml elasticsearch-exporter-values.yaml_bak
#sed -i "s/admin_password/${admin_password}/g" elasticsearch-exporter-values.yaml_bak
#helm uninstall prometheus-es-exporter -n ${NS}
#helm upgrade --debug --install --reuse-values -f elasticsearch-exporter-values.yaml_bak \
#  prometheus-es-exporter prometheus-community/prometheus-elasticsearch-exporter -n ${NS}

pushd `pwd`
cd ..
cp configmap.yaml configmap.yaml_bak
sed -i "s/eks_project/${eks_project}/g" configmap.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" configmap.yaml_bak
sed -i "s/admin_password/${admin_password}/g" configmap.yaml_bak
kubectl -n ${NS} apply -f configmap.yaml_bak
popd

kubectl rollout restart statefulset.apps/alertmanager-prometheus-kube-prometheus-alertmanager -n ${NS}
kubectl rollout restart statefulset.apps/prometheus-prometheus-kube-prometheus-prometheus -n ${NS}
kubectl rollout restart deploy/prometheus-grafana -n ${NS}
#kubectl -n ${NS} logs -f prometheus-prometheus-kube-prometheus-prometheus-0 -c config-reloader
sleep 20

kubectl -n ${NS} apply -f prometheus-kube-state-metrics-fix.yaml

kubectl -n ${NS} get prometheusrule
kubectl -n ${NS} describe prometheusrule sample-app-down
#sum(rate(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[15m])) by (namespace, pod)
#count(kube_pod_status_phase{namespace="devops-dev", pod=~"tz-sample-app.*", phase="Failed"}) by (namespace) > 2

kubectl run -it busybox --image=alpine:3.6 -n ${NS} --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "monitoring" } } }' -- sh
#kubectl -n ${NS} exec -it busybox -- sh
#nc -zv prometheus-kube-prometheus-alertmanager.monitoring.svc.cluster.local
#kubectl -n ${NS} exec -it busybox -- sh
apk update && apk add curl &&
export IFS=";" &&
ITEMS="CPUThrottlingHigh;Watchdog"
for item in $ITEMS; do
  curl http://prometheus-kube-prometheus-alertmanager.monitoring.svc.cluster.local:9093/api/v1/silences -d '{
        "matchers": [
          {
            "name": "alertname",
            "value": "'${item}'*",
            "isRegex": true
          }
        ],
        "startsAt": "2021-07-25T23:11:44.603Z",
        "endsAt": "2030-12-04T08:35:54.713Z",
        "createdBy": "api",
        "comment": "Silence",
        "status": {
          "state": "active"
        }
  }'
done

exit 0

kubectl -n ${NS} patch pvc prometheus-grafana -p '{"metadata":{"finalizers":null}}'
kubectl -n ${NS} patch pv pvc-d4973d7f-c496-4edc-b8b5-ee69e5822490 -p '{"metadata":{"finalizers":null}}'
kubectl -n ${NS} patch pod prometheus-grafana-6d558f87d9-w4ks2 -p '{"metadata":{"finalizers":null}}'

kubectl -n ${NS} patch prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-prometheus-kube-prometheus-prometheus-0 -p '{"metadata":{"finalizers":null}}'
kubectl -n ${NS} patch pv pvc-93873cc3-9f07-4bc1-b4a0-559b6a427e83 -p '{"metadata":{"finalizers":null}}'
kubectl -n ${NS} patch pod prometheus-prometheus-kube-prometheus-prometheus-0 -p '{"metadata":{"finalizers":null}}'

