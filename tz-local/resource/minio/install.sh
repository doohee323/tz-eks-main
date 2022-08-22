#!/usr/bin/env bash

# https://malwareanalysis.tistory.com/251

#bash /vagrant/tz-local/resource/minio/install.sh
cd /vagrant/tz-local/resource/minio

helm repo add minio https://charts.min.io/
#kubectl delete namespace minio
kubectl create namespace minio
#helm uninstall my-release -n minio
#--reuse-values
helm upgrade --debug --install my-release minio/minio \
  -n minio \
  --set mode=distributed \
  -f values.yaml
#helm -n minio get values my-release > old_values.yaml

kubectl apply -f minio-ingress.yaml -n minio

helm install --set buckets[0].name=bucket1,buckets[0].policy=none,buckets[0].purge=false minio/minio
helm install --set policies[0].name=mypolicy,policies[0].statements[0].resources[0]='arn:aws:s3:::bucket1',policies[0].statements[0].actions[0]='s3:ListBucket',policies[0].statements[0].actions[1]='s3:GetObject' minio/minio
helm install --set users[0].accessKey=accessKey,users[0].secretKey=secretKey,users[0].policy=none,users[1].accessKey=accessKey2,users[1].secretRef=existingSecret,users[1].secretKey=password,users[1].policy=none minio/minio

# aws marketplace
# https://min.io/product/multicloud-elastic-kubernetes-service/deploy


