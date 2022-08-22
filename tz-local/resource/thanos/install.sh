#!/usr/bin/env bash

#bash /vagrant/tz-local/resource/thanos/install.sh
cd /vagrant/tz-local/resource/thanos

# thanos
#https://medium.com/nerd-for-tech/deep-dive-into-thanos-part-ii-8f48b8bba132
#https://aws.amazon.com/blogs/opensource/improving-ha-and-long-term-storage-for-prometheus-using-thanos-on-eks-with-s3/
#https://thanos.io/tip/operating/cross-cluster-tls-communication.md/
#https://thanos.io/tip/thanos/storage.md/
#https://particule.io/en/blog/thanos-monitoring/
#https://thanos.io/tip/thanos/quick-tutorial.md/

#https://tanzu.vmware.com/developer/guides/kubernetes/prometheus-multicluster-monitoring/

helm repo add bitnami https://charts.bitnami.com/bitnami
helm delete my-release -n monitoring
kubectl create secret generic thanos-objstore-secret --from-file=thanos-objstore.yml -n monitoring
helm upgrade --debug --install my-release bitnami/thanos -n monitoring -f value.yaml

k -n monitoring patch deployment/my-release-thanos-compactor -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "monitoring"}}}}}'
k -n monitoring patch deployment/my-release-thanos-query -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "monitoring"}}}}}'
k -n monitoring patch deployment/my-release-thanos-query-frontend -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "monitoring"}}}}}'
k -n monitoring patch statefulset/my-release-thanos-storegateway -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "monitoring"}}}}}'


#https://tanzu.vmware.com/developer/guides/prometheus-multicluster-monitoring/#step-2-install-and-configure-thanos
#my-release-thanos-query.monitoring.svc.cluster.local (port 9090)

kubectl get svc -n morning

prometheus sever - lma-prometheus:9090
manager - lma-manager:9093
thanos sidecar - lma-thanos-discovery:10901


exit 0

#
## mimir
##https://grafana.com/docs/mimir/next/operators-guide/deploy-grafana-mimir/getting-started-helm-charts/
#
#helm -n mimir-test uninstall mimir grafana/mimir-distributed
#helm -n mimir-test install mimir grafana/mimir-distributed -f custom.yaml \
#  --set nodeSelector.team=devops \
#  --set nodeSelector.environment=sec
#
#
#helm -n mimir-test upgrade mimir grafana/mimir-distributed -f custom.yaml \
#  --set nodeSelector.team=devops \
#  --set nodeSelector.environment=sec
#
#
#kubectl -n mimir-test get pods
#
#kubectl -n mimir-test  patch deployment/mimir-nginx -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "sec"}}}}}'
#kubectl -n mimir-test  patch deployment/mimir-query-frontend -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "sec"}}}}}'
#kubectl -n mimir-test  patch deployment/mimir-querier -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "sec"}}}}}'
#kubectl -n mimir-test  patch statefulset/mimir-ingester -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "sec"}}}}}'
#
#
#


{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "Statement",
          "Effect": "Allow",
          "Principal": {
            "AWS": "*"
          },
          "Action": [
              "s3:ListBucket",
              "s3:GetObject",
              "s3:DeleteObject",
              "s3:PutObject"
          ],
          "Resource": [
              "arn:aws:s3:::devops-thanos-eks-main/*",
              "arn:aws:s3:::devops-thanos-eks-main"
          ]
      }
  ]
}
