#!/usr/bin/env bash

cd /vagrant/tz-local/resource/redis
#bash /vagrant/tz-local/resource/redis/install.sh

#set -x
shopt -s expand_aliases

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
NS=devops-dev

alias kubectl="kubectl --kubeconfig ~/.kube/config"
alias k="kubectl --kubeconfig ~/.kube/config"

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

NAME=ssakdook
#helm uninstall redis-cluster-${NAME} -n ${NS}
helm upgrade --debug --install --reuse-values redis-cluster-${NAME} \
  --set cluster.replicaCount=1 \
  --set auth.enabled=false \
  --set securityContext.enabled=true \
  --set securityContext.fsGroup=2000 \
  --set securityContext.runAsUser=1000 \
  --set volumePermissions.enabled=true \
  --set master.persistence.enabled=true \
  --set replica.persistence.enabled=true \
  --set master.persistence.enabled=true \
  --set master.persistence.path=/data \
  --set master.persistence.size=15Gi \
  --set master.persistence.storageClass=gp2 \
  --set replica.persistence.enabled=true \
  --set replica.persistence.path=/data \
  --set replica.persistence.size=15Gi \
  --set replica.persistence.storageClass=gp2 \
bitnami/redis -n ${NS}

k patch StatefulSet/redis-cluster-${NAME}-master -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n ${NS}
k patch StatefulSet/redis-cluster-${NAME}-master -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "dev"}}}}}' -n ${NS}
k patch StatefulSet/redis-cluster-${NAME}-replicas -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops"}}}}}' -n ${NS}
k patch StatefulSet/redis-cluster-${NAME}-replicas -p '{"spec": {"template": {"spec": {"nodeSelector": {"environment": "dev"}}}}}' -n ${NS}
k patch StatefulSet/redis-cluster-${NAME}-replicas -p '{"spec": {"template": {"spec": {"replicas": 1}}}}' -n ${NS}
k patch svc redis-cluster-${NAME}-master -p '{"spec": {"type": "LoadBalancer"}}' -n ${NS}

k scale --replicas=1 StatefulSet redis-cluster-${NAME}-replicas -n ${NS}
k scale --replicas=1 StatefulSet redis-cluster-${NAME}-replicas -n ${NS}

sleep 240

#-. 방화벽 적용
svc_elb=`kubectl get svc redis-cluster-${NAME}-master -n ${NS} | awk '{print $4}' | tail -n 1`
echo ${svc_elb}
PORT=6379

if [[ "${svc_elb}" != "" ]]; then
  elb=`echo ${svc_elb} | awk -F'.' '{ print $1 }' | awk -F'-' '{ for(i=1;i<=NF;i++) print $i }' | head -n -1 | tr '\n' '-'`
  elb=${elb::-1}
  echo elb: $elb
  securityGroup=`aws elb describe-load-balancers --load-balancer-names ${elb} | grep SecurityGroups -A 1 | tail -n 1 | awk '{print $1}' | sed 's/\"//g'`
  if [[ "${securityGroup}" == "" ]]; then
    securityGroup=`aws elbv2 describe-load-balancers --names ${elb} | grep SecurityGroups -A 1 | tail -n 1 | awk '{print $1}' | sed 's/\"//g'`
  fi
  echo securityGroup: ${securityGroup}
fi

aws ec2 revoke-security-group-ingress --group-id ${securityGroup} \
  --protocol tcp --port ${PORT} --cidr 0.0.0.0/0
vpc_cidr_block="10.40.0.0/16"
EKS_EXTERNAL_IP="13.209.94.107/32"
SOURCES=(218.153.127.33/32:office 3.35.170.100/32:jenkins 98.234.34.27/32:doohee-home ${EKS_EXTERNAL_IP}:EKS_EXTERNAL_IP 20.10.0.0/16:devops-util ${vpc_cidr_block}:${eks_project})
for str in "${SOURCES[@]}"; do
  item=($(echo ${str} | tr ':' ' '))
  aws ec2 authorize-security-group-ingress --group-id ${securityGroup} \
    --ip-permissions "IpProtocol"="tcp","FromPort"=${PORT},"ToPort"=${PORT},"IpRanges"="[{CidrIp=${item[0]},Description=${item[1]}}]"
done

#-. rename-command FLUSHDB 제거
kubectl -n ${NS} patch cm redis-cluster-${NAME}-configuration -p '{"data": {"master.conf": "dir /data"}}'
#kubectl -n ${NS} edit cm redis-cluster-${NAME}-configuration
#comment in redis-cluster-${NAME}-configuration
# #rename-command FLUSHDB ""
# #rename-command FLUSHALL ""

#redis-cluster-${NAME}-master.default.svc.cluster.local for read/write operations (port 6379)
#redis-cluster-${NAME}-replicas.default.svc.cluster.local for read-only operations (port 6379)

#-. pod 재시작
kubectl rollout restart statefulset.apps/redis-cluster-${NAME}-master -n ${NS}
sleep 60

#-. bastion에서 FLUSHDB 실행
kubectl -n extension-dev exec -it pod/devops-bastion \
  -- redis-cli -h redis-cluster-${NAME}-master.${NS}.svc.cluster.local -p 6379 FLUSHDB

echo ${svc_elb}
echo securityGroup: ${securityGroup}

##-. rount53 변경
#SVC_DOMAIN=tzcorp.com
#HOSTZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == '${SVC_DOMAIN}.']" | grep '"Id"'  | awk '{print $2}' | sed 's/\"//g;s/,//' | cut -d'/' -f3)
#echo $HOSTZONE_ID
#
#CUR_ELB=$(aws route53 list-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} --query "ResourceRecordSets[?Name == 'redis-dev.${NAME}.${SVC_DOMAIN}.']" | grep 'Value' | awk '{print $2}' | sed 's/"//g')
#echo "CUR_ELB: $CUR_ELB"
#if [[ "${CUR_ELB}" != "${svc_elb}" ]]; then
#  aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
#   --change-batch '{ "Comment": "redis-dev.'"${NAME}"'.'"${eks_project}"' utils", "Changes": [{"Action": "DELETE", "ResourceRecordSet": {"Name": "redis-dev.'"${NAME}"'.'"${SVC_DOMAIN}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${CUR_ELB}"'"}]}}]}'
#  aws route53 change-resource-record-sets --hosted-zone-id ${HOSTZONE_ID} \
#   --change-batch '{ "Comment": "redis-dev.'"${NAME}.${eks_project}"' utils", "Changes": [{"Action": "CREATE", "ResourceRecordSet": { "Name": "redis-dev.'"${NAME}.${SVC_DOMAIN}"'", "Type": "CNAME", "TTL": 120, "ResourceRecords": [{"Value": "'"${svc_elb}"'"}]}}]}'
#fi
#
#echo redis-cli -h redis-dev.${NAME}.${SVC_DOMAIN} -p 6379
#kubectl -n ${NS} exec -it pod/devops-bastion \
#  -- redis-cli -h redis-dev.${NAME}.${SVC_DOMAIN} -p 6379

exit 0

nc -zv redis-cluster-${NAME}-master.${NS}.svc.cluster.local 6379
#sudo apt-get install redis-tools -y
redis-cli -h redis-cluster-${NAME}-master.${NS}.svc.cluster.local -p 6379
# set password
#redis-cli -h redis-cluster-${NAME}-master.${NS}.svc.cluster.local -p 6379 -a CONFIG set requirepass 1234qwer
#redis-cli -h redis-cluster-${NAME}-master.${NS}.svc.cluster.local -p 6379 -a 1234qwer CONFIG set requirepass 1111
#redis-cli -h redis-cluster-${NAME}-master.${NS}.svc.cluster.local -p 6379 -a 1111 CONFIG set requirepass 1234qwer

#export REDIS_PASSWORD=$(kubectl get secret --namespace ${NS} redis-cluster -o jsonpath="{.data.redis-password}" | base64 --decode)
#echo $REDIS_PASSWORD


