#!/usr/bin/env bash

#set -x

## AWS EKS cluster를 생성하지 않은 IAM user에게 cluster 컨트롤 권한 부여하기
## https://huzz.tistory.com/70
## https://medium.com/@HoussemDellai/rbac-with-kubernetes-in-minikube-4deed658ea7b

cd /vagrant/tz-local/resource/makeuser/k8s

USER_ID='doohee'
GROUP_ID='devops'

echo "1. Create a client certificate"
mkdir cert && cd cert
# Generate a key 
openssl genrsa -out ${USER_ID}.key 2048
# CSR
openssl req -new -key ${USER_ID}.key -out ${USER_ID}.csr -subj "/CN=${USER_ID}/O=${GROUP_ID}"
# CRT (certificate)
openssl x509 -req -in ${USER_ID}.csr -CA ~/.minikube/ca.crt -CAkey ~/.minikube/ca.key -CAcreateserial -out ${USER_ID}.crt -days 500

echo "2. Create a user"
# Set a user entry in kubeconfig
# ** under cert folder
kubectl config set-credentials ${USER_ID} --client-certificate=${USER_ID}.crt --client-key=${USER_ID}.key
# Set a context entry in kubeconfig
kubectl config get-contexts
kubectl config set-context ${USER_ID}-context --cluster=minikube --user=${USER_ID}
# kubectl config view

# 2.3. Switching to the created user
kubectl config use-context ${USER_ID}-context
kubectl config current-context # check the current context
#kubectl create namespace ns-test # Error from server (Forbidden): namespaces is forbidden: User "${USER_ID}" cannot create resource "namespaces" in API group "" at the cluster scope

echo "3. Grant access to the user"
# Create a Role and BindingRole
kubectl config use-context minikube
kubectl apply -f makeuser/${USER_ID}.yaml
kubectl get roles
kubectl get rolebindings

kubectl config use-context ${USER_ID}-context
kubectl create namespace ns-test # won't succeed, Forbidden
kubectl get pods # this will succeed !

rm -Rf ${USER_ID}.crt ${USER_ID}.csr ${USER_ID}.key

kubectl config use-context minikube

exit 0


