#!/usr/bin/env bash

#bash /vagrant/tz-local/resource/istio/install.sh
cd /vagrant/tz-local/resource/istio

LEC_HOME=/vagrant/tz-local/resource/istio
kubectl apply -f "$LEC_HOME"

kubectl -n istio-system delete -f istio-ingress.yaml
kubectl -n istio-system apply -f istio-ingress.yaml

#kubectl apply -f 4-1.auth.yaml
TOKEN=$(kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | grep ^token: | sed 's/token:[ ]*/Token:\n/')
echo $TOKEN

exit 0


kubectl delete -f 2-istio-eks.yaml
kubectl delete -f 1-istio-init.yaml

kubectl apply -f 1-istio-init.yaml
kubectl apply -f 2-istio-eks.yaml

#echo YWRtaW4= | base64 -d
#echo admin | base64
pswd='Dlwpdldps!323'
#echo $pswd | base64

kubectl delete -f 3-kiali-secret.yaml
kubectl apply -f 3-kiali-secret.yaml

# label namespace
kubectl describe ns devops
kubectl label namespace devops istio-injection=enabled

kubectl delete -f 4-example.yaml
kubectl apply -f 4-example.yaml

kubectl -n istio-system apply -f istio-ingress.yaml
curl --insecure https://kiali.istio-system.eks-main.tzcorp.com/kiali

kubectl apply -f 4-label-default-namespace.yaml
kubectl delete -f 5-application-no-istio.yaml
kubectl apply -f 5-application-no-istio.yaml

https://kiali.istio-system.eks-main.tzcorp.com/

kubectl apply -f /vagrant/tz-local/resource/istio/istio-fleetman/_course_files/warmup-exercise/4-application-full-stack.yaml

#kubectl get namespace/vault --show-labels
#kubectl label namespace vault istio-injection=enabled
#kubectl label namespaces vault istio-injection-

LEC_HOME=/vagrant/tz-local/resource/istio-fleetman

# ====================================================================================

kubectl apply -f "$LEC_HOME/_course_files/1 Telemetry/1-istio-init.yaml"
kubectl apply -f 2-istio-eks.yaml
kubectl apply -f "$LEC_HOME/_course_files/1 Telemetry/3-kiali-secret.yaml"
kubectl apply -f "$LEC_HOME/_course_files/1 Telemetry/4-label-default-namespace.yaml"
kubectl apply -f "$LEC_HOME/_course_files/1 Telemetry/5-application-no-istio.yaml"

kubectl apply -f "$LEC_HOME/_course_files/2 Traffic - Starting Files/5-application-no-istio.yaml"
kubectl delete -f "$LEC_HOME/_course_files/2 Traffic Solution - Ending Files/5-application-no-istio.yaml"
kubectl apply -f "$LEC_HOME/_course_files/2 Traffic Solution - Ending Files/5-application-no-istio.yaml"
kubectl apply -f "$LEC_HOME/_course_files/2 Traffic Solution - Ending Files/6-istio-rules.yaml"

kubectl delete -f "$LEC_HOME/_course_files/3 Gateways/6-istio-rules.yaml"
kubectl apply -f "$LEC_HOME/_course_files/3 Gateways/5-application-no-istio.yaml"
kubectl apply -f "$LEC_HOME/_course_files/3 Gateways/6-istio-rules.yaml"

kubectl apply -f "$LEC_HOME/_course_files/3 Gateways Solution/5-application-no-istio.yaml"
kubectl apply -f "$LEC_HOME/_course_files/3 Gateways Solution"

kubectl delete -f "$LEC_HOME/_course_files/6 Circuit Breaking"

