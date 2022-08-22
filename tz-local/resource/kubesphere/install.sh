#!/usr/bin/env bash

#https://kubesphere.io/docs/quick-start/minimal-kubesphere-on-k8s/
#https://kubesphere.io/docs/installing-on-kubernetes/hosted-kubernetes/install-kubesphere-on-eks/#install-kubesphere-on-eks
#https://kubesphere.io/docs/multicluster-management/import-cloud-hosted-k8s/import-aws-eks/

#bash /vagrant/tz-local/resource/kubesphere/install.sh
cd /vagrant/tz-local/resource/kubesphere

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

kubectl delete -f https://github.com/kubesphere/ks-installer/releases/download/v3.1.1/kubesphere-installer.yaml
kubectl delete -f https://github.com/kubesphere/ks-installer/releases/download/v3.1.1/cluster-configuration.yaml

kubectl delete namespace istio-system
kubectl delete namespace kube-federation-system
kubectl delete namespace kubeedge
kubectl delete namespace kubesphere-controls-system
kubectl delete namespace kubesphere-devops-system
kubectl delete namespace kubesphere-logging-system
kubectl delete namespace kubesphere-monitoring-federated
kubectl delete namespace kubesphere-monitoring-system
kubectl delete namespace kubesphere-system

#rm -Rf cluster-configuration.yaml
#rm -Rf kubesphere-installer.yaml
#wget https://github.com/kubesphere/ks-installer/releases/download/v3.1.1/kubesphere-installer.yaml
#wget https://github.com/kubesphere/ks-installer/releases/download/v3.1.1/cluster-configuration.yaml
#vi https://github.com/kubesphere/ks-installer/blob/master/scripts/kubesphere-delete.sh
#bash kubesphere-delete.sh
#kubectl delete namespace kubesphere-alerting-system kubesphere-controls-system kubesphere-devops-system kubesphere-devops-worker kubesphere-logging-system kubesphere-monitoring-system kubesphere-monitoring-federated openpitrix-system kubesphere-system

kubectl apply -f kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml
#kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

sleep 120

jwtSecret=$(kubectl -n kubesphere-system get cm kubesphere-config -o yaml | grep -v "apiVersion" | grep jwtSecret | awk '{print $2}' | sed "s/\"//g;s/,//g")
echo "jwtSecret: ${jwtSecret}"

#TOKEN=$(kubectl -n kubesphere-system get secret $(kubectl -n kubesphere-system get sa kubesphere -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)
#kubectl config set-credentials kubesphere --token=${TOKEN}
#kubectl config set-context --current --user=kubesphere

kubectl patch svc ks-console -n kubesphere-system -p '{"spec": {"type": "LoadBalancer"}}'
sleep 30
echo http://$(kubectl get svc ks-console -n kubesphere-system | grep ks-console | awk '{print $4}')
echo admin / P@88w0rd

bash /vagrant/tz-local/resource/docker-repo/install.sh
k patch daemonset/node-exporter -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-monitoring-system
k patch statefulset/prometheus-k8s -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-monitoring-system
k patch deployment/notification-manager-deployment -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-monitoring-system
k patch deployment/ks-console -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-system
k patch deployment/ks-installer -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-system
k patch deployment/kubefed-admission-webhook -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kube-federation-system
k patch statefulset/snapshot-controller -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kube-system
k patch deployment/tower -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kubesphere-system

cd harbor
cp -Rf harbor-ingress.yaml harbor-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" harbor-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" harbor-ingress.yaml_bak
sed -i "s|NS|devops|g" harbor-ingress.yaml_bak
k delete -f harbor-ingress.yaml_bak -n devops
k apply -f harbor-ingress.yaml_bak -n devops

echo admin / Harbor12345

# change host type cluster
#kubectl patch cc/ks-installer -n kubesphere-system -p '{"spec": {"multicluster": {"clusterRole": "none"}}}'
#kubectl edit cc/ks-installer -n kubesphere-system
#kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

