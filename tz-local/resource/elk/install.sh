#!/usr/bin/env bash

#https://phoenixnap.com/kb/elasticsearch-helm-chart
#https://www.elastic.co/guide/en/elasticsearch/reference/7.1/configuring-tls-docker.html
#https://github.com/elastic/helm-charts/tree/7.15/elasticsearch/examples/multi

#bash /vagrant/tz-local/resource/elk/install.sh
cd /vagrant/tz-local/resource/elk

shopt -s expand_aliases

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
export AWS_ACCESS_KEY_ID=$(prop 'credentials' 'aws_access_key_id')
export AWS_SECRET_ACCESS_KEY=$(prop 'credentials' 'aws_secret_access_key')
NS=elk
export STACK_VERSION=7.13.2

#curl -O https://raw.githubusercontent.com/elastic/helm-charts/master/elasticsearch/examples/minikube/values.yaml
alias k="kubectl -n ${NS} --kubeconfig ~/.kube/config"

helm repo add elastic https://helm.elastic.co
helm search hub elasticsearch
helm repo update

# make secrets in k8s
helm uninstall elasticsearch -n ${NS}
kubectl delete namespace ${NS}
kubectl create namespace ${NS}
sudo chown -Rf vagrant:vagrant /var/run/docker.sock

export DNS_NAME=elasticsearch-master
export NAMESPACE=${NS}
bash create-elastic-certificates.sh

#https://github.com/elastic/helm-charts/blob/master/elasticsearch/values.yaml
sleep 10

kubectl -n elk create secret generic aws-s3-keys \
  --from-literal=access-key-id=${AWS_ACCESS_KEY_ID} \
  --from-literal=access-secret-key=${AWS_SECRET_ACCESS_KEY}

cp es_values.yaml es_values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" es_values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" es_values.yaml_bak
sed -i "s/ADMIN_PASSWORD/${admin_password}/g" es_values.yaml_bak
#helm uninstall elasticsearch -n ${NS}
helm upgrade --debug --install --reuse-values -f es_values.yaml_bak elasticsearch elastic/elasticsearch --version ${STACK_VERSION} -n ${NS}

k patch statefulset/elasticsearch-master -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}'
k patch statefulset/elasticsearch-master -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "elk"}}}}}'
kubectl rollout restart statefulset.apps/elasticsearch-master -n ${NS}
#k get pods | grep elasticsearch-master | awk '{print $1}' | xargs kubectl -n ${NS} delete pod
kubectl get csr -o name | xargs kubectl certificate approve

cp es_data_values.yaml es_data_values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" es_data_values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" es_data_values.yaml_bak
sed -i "s/ADMIN_PASSWORD/${admin_password}/g" es_data_values.yaml_bak
#helm uninstall elasticsearch-data -n ${NS}
helm upgrade --debug --install --reuse-values -f es_data_values.yaml_bak elasticsearch-data elastic/elasticsearch --version ${STACK_VERSION} -n ${NS}
k patch statefulset/elasticsearch-data -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}'
k patch statefulset/elasticsearch-data -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "elk"}}}}}'
kubectl rollout restart statefulset.apps/elasticsearch-data -n ${NS}

#kubectl -n ${NS} port-forward svc/elasticsearch-master 9200
#curl --insecure -v -u elastic:wPFNxwADbRtvMp6HYdlI https://es.elk.eks-main.tzcorp.com

sleep 60

#helm test elasticsearch -n ${NS}
cp kb_values.yaml kb_values.yaml_bak
sed -i "s/TEAM/devops/g" kb_values.yaml_bak
sed -i "s/STAGING/elk/g" kb_values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" kb_values.yaml_bak

#helm uninstall kibana -n ${NS}
helm upgrade --debug --install --reuse-values -f kb_values.yaml_bak kibana elastic/kibana --version ${STACK_VERSION} -n ${NS}
kubectl get csr -o name | xargs kubectl certificate approve

sleep 100

#helm uninstall metricbeat -n ${NS}
#helm install metricbeat elastic/metricbeat -n ${NS}
#kubectl get csr -o name | xargs kubectl certificate approve

cp -Rf elk-ingress.yaml elk-ingress.yaml_bak
sed -i "s/eks_project/${eks_project}/g" elk-ingress.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" elk-ingress.yaml_bak
k delete -f elk-ingress.yaml_bak -n ${NS}
k apply -f elk-ingress.yaml_bak -n ${NS}

#curl -ks -X PUT 'https://elastic:${admin_password}@es.elk.${eks_project}.${eks_domain}/_security/user/svc_kibana' -H 'Content-Type: application/json' -d'
#{
#  "password" : "wPFNxwADbRtvMp6HYdlI",
#  "roles" : [ "kibana_system" ],
#  "full_name" : "",
#  "email" : ""
#}'

echo https://kibana.elk.${eks_project}.${eks_domain}
curl -v kibana.elk.${eks_project}.${eks_domain}

exit 0

helm uninstall logstash -n ${NS}
cp -Rf ls_values.yaml ls_values.yaml_bak
sed -i "s/TEAM/devops/g" ls_values.yaml_bak
sed -i "s/STAGING/elk/g" ls_values.yaml_bak
sed -i "s/ADMIN_PASSWORD/${admin_password}/g" ls_values.yaml_bak
helm upgrade --debug --install --reuse-values -f ls_values.yaml_bak logstash elastic/logstash --version ${STACK_VERSION} -n ${NS}
kubectl get csr -o name | xargs kubectl certificate approve
#curl --insecure -v -u elastic:${admin_password} https://elasticsearch-master:9200
#curl --insecure -v -u elastic:${admin_password} https://es.${eks_domain}

#curl -XGET http://<elasticsearch IP>:9200 -u logstash_system:l12345 or
#curl -XGET https://<elasticsearch IP>:9200 -u logstash_system:l12345 -k

curl -XGET https://es.${eks_domain} -u logstash_system:l12345 or
curl -XGET https://es.${eks_domain}/my_index-000001 -u elastic:${admin_password}
curl -XGET https://es.${eks_domain}/my_index-000001 -u logstash_system:${admin_password}

#xpack.monitoring.elasticsearch.username: "logstash_system"
#xpack.monitoring.elasticsearch.password: => "l12345"

helm uninstall filebeat -n ${NS}
cp -Rf fb_values.yaml fb_values.yaml_bak
sed -i "s/ADMIN_PASSWORD/${admin_password}/g" fb_values.yaml_bak
sed -i "s/TEAM/devops/g" fb_values.yaml_bak
sed -i "s/STAGING/elk/g" fb_values.yaml_bak
sed -i "s/eks_project/${eks_project}/g" fb_values.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" fb_values.yaml_bak
helm upgrade --install --reuse-values -f fb_values.yaml_bak filebeat elastic/filebeat --version ${STACK_VERSION} -n ${NS}
#https://www.elastic.co/guide/en/beats/filebeat/current/running-on-kubernetes.html

#https://danawalab.github.io/elastic/2020/05/20/Elasticsearch-basic-security.html
#https://discuss.elastic.co/t/elasticsearch-enable-security-issues/225413

echo "
##[ ES ]##########################################################
- Url: http://kibana.default.${eks_project}.${eks_domain}
#######################################################################
" >> /vagrant/info
cat /vagrant/info

exit 0

cp -Rf metricbeat-kubernetes.yaml metricbeat-kubernetes.yaml_bak
sed -i "s/changeme/${admin_password}/g" metricbeat-kubernetes.yaml_bak
sed -i "s/eks_project/${eks_project}/g" metricbeat-kubernetes.yaml_bak
sed -i "s/namespace: es/namespace: ${NS}/g" metricbeat-kubernetes.yaml_bak
kubectl delete -f metricbeat-kubernetes.yaml_bak -n ${NS}
kubectl apply -f metricbeat-kubernetes.yaml_bak -n ${NS}

#kubectl run -it busybox --image=alpine:3.6 -n monitoring --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "prod" } } }' -- sh
#kubectl run -it busybox --image=alpine:3.6 -n elk --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "elk" } } }' -- sh
#nc -zv prometheus-kube-state-metrics.monitoring.svc.cluster.local 8080
#curl http://prometheus-kube-state-metrics.monitoring.svc.cluster.local:8080/metrics
#nc -zv elasticsearch-master.elk.svc.cluster.local 9200
#curl http://elasticsearch-master.elk.svc.cluster.local:9200

kubectl -n elk exec -it $(kubectl -n elk get pod | grep kibana-kibana | awk '{print $1}') -- kibana-encryption-keys generate

kubectl -n elk exec -it $(kubectl -n elk get pod | grep elasticsearch-master-0 | awk '{print $1}') -- ssh
#  elasticsearch-keystore remove xpack.notification.email.account.gmail_account.smtp.secure_password
  elasticsearch-keystore add xpack.notification.email.account.gmail_account.smtp.secure_password
  elasticsearch-keystore add xpack.notification.email.account.elastic.smtp.secure_password
  elasticsearch-keystore add xpack.notification.slack.account.monitoring.secure_url
  elasticsearch-keystore add xpack.notification.slack.account.elastic.secure_url
  # https://hooks.slack.com/services/xxxxxxxxxx/xxxxxxxxxx/xxxxxxxxxx
  elasticsearch-keystore list


POST _xpack/watcher/watch/_execute
{
  "watch": {
    "trigger": {
      "schedule": {
        "interval": "1m"
      }
    },
    "input": {
      "simple": {
      }
    },
    "actions": {
      "email": {
        "email": {
          "to": "doohee323@gmail.com",
          "subject": "subject11",
          "body": {
            "html": "HTML22222"
          }
        }
      }
    }
  }
}


POST _nodes/reload_secure_settings
{
  "secure_settings_password": "xpack.notification.email.account.elastic.smtp.secure_password"
}



apiVersion: v1
kind: Secret
metadata:
  name: one-secure-settings-secret
type: Opaque
data:
  gcs.client.default.credentials_file: RWxhc3RpYyBDbG91ZCBvbiBLOHMgKEVDSykK


kubectl run -it busybox --image=alpine:3.6 -n elk --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "elk" } } }' -- sh
curl --insecure https://elastic:${admin_password}@elasticsearch-master.elk.svc.cluster.local:9200
