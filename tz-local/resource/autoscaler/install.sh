#!/usr/bin/env bash

source /root/.bashrc
cd /vagrant/tz-local/resource/autoscaler

kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

exit 0
