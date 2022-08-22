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

bash kubesphere-delete.sh

wget https://github.com/kubesphere/ks-installer/releases/download/v3.1.1/kubesphere-installer.yaml
wget https://github.com/kubesphere/ks-installer/releases/download/v3.1.1/cluster-configuration.yaml

kubectl delete -f kubesphere-installer.yaml
kubectl delete -f cluster-configuration.yaml

#kubectl get apiservices | grep False
#kubectl delete apiservice/v1beta1.metrics.k8s.io

kubectl apply -f kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml
#kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

kubectl patch svc ks-console -n kubesphere-system -p '{"spec": {"type": "LoadBalancer"}}'

jwtSecret=$(kubectl -n kubesphere-system get cm kubesphere-config -o yaml | grep -v "apiVersion" | grep jwtSecret | awk '{print $2}' | sed 's/"//g')
echo "jwtSecret: ${jwtSecret}"
cp -Rf cluster-configuration2.yaml cluster-configuration2.yaml_bak
sed -i "s/JWTSECRET/${jwtSecret}/g" cluster-configuration2.yaml_bak
kubectl apply -f cluster-configuration2.yaml_bak
#kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

#kubectl patch svc minio -n kubesphere-system -p '{"spec": {"type": "LoadBalancer"}}'
#openpitrixminioaccesskey / openpitrixminiosecretkey

# grafana
#  monitoring:
#    grafana:
#      enabled: true
#
#GF_PATHS_DATA='/var/lib/grafana' is not writable.
#kubectl edit deployment/grafana -n kubesphere-monitoring-system
#      securityContext:
#        runAsUser: 65534
#        runAsGroup: 65534
#        fsGroup: 65534
#kubectl patch svc grafana -n kubesphere-monitoring-system -p '{"spec": {"type": "LoadBalancer"}}'

# change host type cluster
#kubectl patch cc/ks-installer -n kubesphere-system -p '{"spec": {"multicluster": {"clusterRole": "none"}}}'
#kubectl patch cc/ks-installer -n kubesphere-system -p '{"spec": {"multicluster": {"clusterRole": "host"}}}'
#kubectl edit cc/ks-installer -n kubesphere-system
#kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

# elk
#logging:
#     enabled: True
#     elasticsearchMasterReplica: 1
#     elasticsearchDataReplica: 2
#     elasticsearchVolumeSize: 20Gi
#     logMaxAge: 7
#     elkPrefix: logstash
#     containersLogMountedPath: ""
#     kibana:
#       enabled: False

kubectl -n kubesphere-monitoring-system create secret generic kube-etcd-client-certs

sleep 400

#echo "http://$(kubectl get svc/ks-console -n kubesphere-system | tail -n 1 | awk '{print $4}')"
echo admin / P@88w0rd
