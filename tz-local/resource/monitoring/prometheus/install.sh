#!/usr/bin/env bash

# alert
#https://nws.netways.de/tutorials/2020/10/07/kubernetes-alerting-with-prometheus-alert-manager/
#https://dev.to/cosckoya/prometheus-alertmanager-with-sendgrid-and-slack-api-4f8a
#https://grafana.com/docs/grafana/latest/datasources/cloudwatch/
#https://prometheus.io/docs/instrumenting/exporters/#http
#bash /vagrant/tz-local/resource/monitoring/prometheus/install.sh

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

#custom prometheus alert
#kubectl -n ${NS} get Prometheus/prometheus-kube-prometheus-prometheus -o yaml > prometheus-kube-prometheus-prometheus.yaml
#kubectl -n ${NS} get prometheusrules prometheus-kube-prometheus-alertmanager.rules -o yaml > alertmanager.rules.yaml
kubectl -n ${NS} delete -f alertmanager.rules.yaml
kubectl -n ${NS} apply -f alertmanager.rules.yaml
kubectl -n ${NS} get prometheusrules

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl delete secret thanos-objstore-secret -n monitoring
kubectl create secret generic thanos-objstore-secret --from-file=thanos-objstore.yml -n monitoring

#helm install tz-blackbox-exporter prometheus-community/prometheus-blackbox-exporter -n ${NS}
cp prometheus-values.yaml prometheus-values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" prometheus-values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" prometheus-values.yaml_bak
sed -i "s/admin_password/${admin_password}/g" prometheus-values.yaml_bak
helm upgrade --debug --reuse-values --install prometheus prometheus-community/kube-prometheus-stack \
    -n ${NS} -f prometheus-values.yaml_bak \
    --version ${STACK_VERSION}

kubectl label ns monitoring name=devops-thanos

#alertmanager=$(kubectl -n ${NS} get secrets alertmanager-prometheus-kube-prometheus-alertmanager-generated -o yaml | grep alertmanager.yaml | awk '{print $2}')
#echo $alertmanager | base64 -d > alertmanager.values.yaml

cp alertmanager.values.yaml alertmanager.values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" alertmanager.values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" alertmanager.values.yaml_bak
sed -i "s/admin_password/${admin_password}/g" alertmanager.values.yaml_bak
alertmanager=$(cat alertmanager.values.yaml_bak | base64 -w0)
cp alertmanager-secret-k8s.yaml alertmanager-secret-k8s.yaml_bak
sed -i "s/ALERTMANAGER_ENCODE/${alertmanager}/g" alertmanager-secret-k8s.yaml_bak
kubectl -n ${NS} apply -f alertmanager-secret-k8s.yaml_bak
kubectl rollout restart statefulset.apps/alertmanager-prometheus-kube-prometheus-alertmanager -n ${NS}
sleep 20
#kubectl -n ${NS} logs -f alertmanager-prometheus-kube-prometheus-alertmanager-0 -c config-reloader

helm upgrade --debug --reuse-values --install -f alertmanager.values.yaml_bak prometheus prometheus-community/kube-prometheus-stack \
    -n ${NS} \
    --version ${STACK_VERSION}
kubectl -n ${NS} apply -f /vagrant/tz-local/resource/monitoring/configmap.yaml
kubectl rollout restart statefulset.apps/alertmanager-prometheus-kube-prometheus-alertmanager -n ${NS}

kubectl -n ${NS} apply -f sample-app-rule.yaml
cp sample-app-prod.yaml sample-app-prod.yaml_bak
sed -i "s/eks_project/${eks_project}/g" sample-app-prod.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" sample-app-prod.yaml_bak
kubectl delete -f sample-app-prod.yaml_bak -n devops
cp sample-app-dev.yaml sample-app-dev.yaml_bak
sed -i "s/eks_project/${eks_project}/g" sample-app-dev.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" sample-app-dev.yaml_bak
kubectl delete -f sample-app-dev.yaml_bak -n devops-dev
kubectl apply -f sample-app-prod.yaml_bak -n devops
kubectl apply -f sample-app-dev.yaml_bak -n devops-dev

kubectl -n ${NS} get prometheusrule
#kubectl -n ${NS} describe prometheusrule server-up-time.rules

exit 0

###############################################################
Target:
serviceMonitor/monitoring/prometheus-kube-prometheus-kube-proxy/0 (0/15 up)

$ kubectl edit cm/kube-proxy -n kube-system
...
kind: KubeProxyConfiguration
metricsBindAddress: 0.0.0.0:10249
...
$ kubectl delete pod -l k8s-app=kube-proxy -n kube-system
###############################################################


kubectl -n ${NS} delete pod -l app=prometheus
kubectl -n ${NS} get pod -l app=prometheus
sleep 20
kubectl -n ${NS} logs -f prometheus-prometheus-kube-prometheus-prometheus-0 -c config-reloader

kubectl get prometheusrules prometheus-kube-prometheus-k8s.rules -n ${NS} -o yaml > prometheus-kube-prometheus-k8s.rules.yaml
kubectl apply -f prometheus-kube-prometheus-k8s.rules.yaml -n ${NS}
