#!/usr/bin/env bash

#https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/cluster-autoscaler.html#ca-deploy
#https://sgilvitu.io/posts/2020/10/eks-autoscaling/

source /root/.bashrc
#bash /vagrant/tz-local/resource/autoscaler/install.sh
cd /vagrant/tz-local/resource/autoscaler

kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

exit 0

aws_account_id=$(aws sts get-caller-identity --query Account --output text)

CLUSTER_AUTOSCAILER="/vagrant/tz-local/resource/autoscaler/cluster-autoscaler-chart-values.yaml"
cp "${CLUSTER_AUTOSCAILER}" "${CLUSTER_AUTOSCAILER}_bak"
sed -i "s/aws_account_id/${aws_account_id}/g" "${CLUSTER_AUTOSCAILER}_bak"

aws_region=$(prop 'config' 'region')
sed -i "s/aws_region/${aws_region}/g" "${CLUSTER_AUTOSCAILER}_bak"
eks_project=$(prop 'project' 'project')
sed -i "s/eks_project/${eks_project}/g" "${CLUSTER_AUTOSCAILER}_bak"

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update
helm uninstall cluster-autoscaler --namespace kube-system
helm upgrade --debug --install --reuse-values cluster-autoscaler \
  -n kube-system autoscaler/cluster-autoscaler \
  --values="${CLUSTER_AUTOSCAILER}_bak" \
  --version "9.10.7"
rm -Rf components.yaml
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.1/components.yaml
kubectl apply -f components.yaml

kubectl patch deployment/cluster-autoscaler-aws-cluster-autoscaler -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n kube-system
kubectl patch deployment/cluster-autoscaler-aws-cluster-autoscaler -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n kube-system

SERVICE_ACCOUNT=$(kubectl get serviceaccount -n kube-system | grep cluster-autoscaler | awk '{print $1}')
echo $SERVICE_ACCOUNT

#PATCH_FILE='/vagrant/tz-local/resource/autoscaler/patch.yaml'
#cp -Rf ${PATCH_FILE} ${PATCH_FILE}_bak
#sed -i "s/eks_project/${eks_project}/g" ${PATCH_FILE}_bak
#sed -i "s/AWS_REGION/${aws_region}/g" ${PATCH_FILE}_bak
#kubectl patch deployment/cluster-autoscaler-aws-cluster-autoscaler -n kube-system --patch "$(cat ${PATCH_FILE}_bak)"
##kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler-aws-cluster-autoscaler

kubectl apply -f auto-approve-csr.yaml
kubectl get csr -o name | xargs kubectl certificate approve

#168fc", APIVersion:"v1", ResourceVersion:"2156199", FieldPath:""}): type: 'Normal'
# reason: 'NotTriggerScaleUp' pod didn't trigger scale-up (it wouldn't fit if a new node is added): 4 node(s) didn't match node selector

#kubectl apply -f /vagrant/tz-local/resource/autoscaler/scaling-test.yaml
#kubectl delete -f /vagrant/tz-local/resource/autoscaler/scaling-test.yaml
#watch -n 5 kubectl get nodes

## Affinity ########################################################
#https://aws-diary.tistory.com/123

kubectl get nodes --selector team=devops,environment=dev
#environment: dev team: devops

#kubectl -n devops-dev delete -f scaling-test.yaml
kubectl -n devops-dev apply -f scaling-test.yaml
kubectl -n devops-dev get pods -o wide | grep scaling-test
kubectl get nodes --show-labels | grep devops | grep environment=dev

#kubectl -n devops-dev delete hpa scaling-test
#kubectl -n devops-dev autoscale deployment scaling-test --cpu-percent=10 --min=1 --max=1
#kubectl -n devops-dev apply -f scaling-test-v2.yaml
kubectl get hpa --all-namespaces

kubectl -n devops-dev set resources deployment scaling-test --limits=cpu=100m,memory=600Mi
kubectl -n devops-dev apply -f /vagrant/tz-local/resource/autoscaler/scaling-test.yaml
kubectl -n devops-dev delete -f /vagrant/tz-local/resource/autoscaler/scaling-test.yaml


#vi scaling-test.yaml
#      nodeSelector:
#        team: devops
#        project: twip
#        environment: dev

#export FIRST_NODE_NAME=$(kubectl get nodes -o json | jq -r '.items[2].metadata.name')
#kubectl label nodes ${FIRST_NODE_NAME} disktype=ssd
##kubectl label nodes ${FIRST_NODE_NAME} disktype-

# kubectl get nodes --selector team=twip,environment=dev

kubectl get csr -o name | xargs kubectl certificate approve

# https://qiita.com/hkame/items/1378f9176a26e39d93c7#private-ip%E3%82%A2%E3%83%89%E3%83%AC%E3%82%B9%E6%9E%AF%E6%B8%87%E3%81%AE%E5%8E%9F%E5%9B%A0
kubectl set env -n kube-system daemonset/aws-node MINIMUM_IP_TARGET=10 WARM_IP_TARGET=2
kubectl get daemonset -n kube-system aws-node -o json | jq -r '.spec.template.spec.containers[] |select ( .name == "aws-node" ).env'

exit 0


list1=$(kubectl get csr -o name | xargs kubectl describe | grep 'DNS Names:' | awk '{print $3}' | sort)
list2=$(kubectl get nodes -o name | sed 's/node\///g' | sort)

array=( "${list1[@]/$list2}" ) | sort

kubectl describe certificatesigningrequest.certificates.k8s.io/csr-7jc6l
kubectl describe certificatesigningrequest.certificates.k8s.io/csr-brkf5
kubectl describe certificatesigningrequest.certificates.k8s.io/csr-wxg59
