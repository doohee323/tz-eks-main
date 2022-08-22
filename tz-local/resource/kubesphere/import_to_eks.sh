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

rm -Rf kubesphere-installer.yaml
rm -Rf cluster-configuration.yaml
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
CONSOL_URL=$(kubectl -n kubesphere-system get svc | grep ks-console | head -n 1 | awk '{print $4}')
echo "CONSOL_URL: http://${CONSOL_URL}"
echo admin / P@88w0rd

# 1. get jwtSecret from host cluster
jwtSecret=$(kubectl -n kubesphere-system get cm kubesphere-config -o yaml | grep -v "apiVersion" | grep jwtSecret | awk '{print $2}' | sed 's/"//g')
echo "jwtSecret: ${jwtSecret}"

# 2. register jwtSecret in member cluster
# CRD > ClusterConfiguration > ks-installer > Edit Yaml
#echo http://${CONSOL_URL}/clusters/default/customresources/clusterconfigurations.installer.kubesphere.io/resources
cp -Rf cluster-configuration2.yaml cluster-configuration2.yaml_bak
sed -i "s/JWTSECRET/${jwtSecret}/g" cluster-configuration2.yaml_bak
sed -i "s/clusterRole: none/clusterRole: member/g" cluster-configuration2.yaml_bak
kubectl apply -f cluster-configuration2.yaml_bak
#kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

# 3. get TOKEN from member cluster
TOKEN=$(kubectl -n kubesphere-system get secret $(kubectl -n kubesphere-system get sa kubesphere -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)
echo "${TOKEN}"
kubectl config set-credentials kubesphere --token=${TOKEN}
kubectl config set-context --current --user=kubesphere

# 4. make a kube config
# make a kube config refer to kubesphere_eks-main

# 5. import the member cluster in host cluster
#http://${eks_project}.cluster.tzcorp.com/clusters
#Add cluster > Cluster Name > Direct connection > kubeconfig

######################################################
## unbind a cluster
######################################################
# kubectl delete cluster ${eks_project}

