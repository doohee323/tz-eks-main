#!/usr/bin/env bash

#https://ikcoo.tistory.com/89

cd /vagrant/tz-local/resource/autoscaler

aws_account_id=$(aws sts get-caller-identity --query Account --output text)

CLUSTER_AUTOSCAILER="/vagrant/tz-local/resource/autoscaler/cluster-autoscaler-chart-values.yaml"
cp "${CLUSTER_AUTOSCAILER}" "${CLUSTER_AUTOSCAILER}_bak"
sed -i "s/aws_account_id/${aws_account_id}/g" "${CLUSTER_AUTOSCAILER}_bak"

aws_region=$(prop 'config' 'region')

kubectl get nodes --show-labels | grep node-role.kubernetes.io

#            - ip-10-30-11-77.us-west-1.compute.internal
#            - ip-10-30-3-70.us-west-1.compute.internal
#            - ip-10-30-23-246.us-west-1.compute.internal

kubectl label nodes ip-10-30-11-77.us-west-1.compute.internal requiredkey=iksoonvalue preferredkey1=iksoonvalue1
kubectl label nodes ip-10-30-3-70.us-west-1.compute.internal requiredkey=iksoonvalue preferredkey2=iksoonvalue2

kubectl label nodes ip-10-30-11-77.us-west-1.compute.internal requiredkey- preferredkey1-
kubectl label nodes ip-10-30-3-70.us-west-1.compute.internal requiredkey- preferredkey2-

