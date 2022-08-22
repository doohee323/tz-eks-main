#https://aws.amazon.com/ko/premiumsupport/knowledge-center/eks-persistent-storage/

cd /vagrant/tz-local/resource/persistent-storage

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
AWS_REGION=$(prop 'config' 'region')
eks_project=$(prop 'project' 'project')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

PVC_NAME="prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-prometheus-kube-prometheus-prometheus-0"
SUBNET="ap-northeast-2c"
NAMESPACE="monitoring"

VOLUME_ID=$(kubectl describe pv $(kubectl get pv | grep ${PVC_NAME} | \
  awk '{print $1}') | grep VolumeID | awk '{print $2}' | rev | cut -d"/" -f1  | rev)
echo ${VOLUME_ID}

PV_ID=$(kubectl describe pv $(kubectl get pv | grep ${PVC_NAME} | \
  awk '{print $1}') | grep 'Name:' | awk '{print $2}')
echo ${PV_ID}

SIZE=$(kubectl describe pv $(kubectl get pv | grep ${PVC_NAME} | \
  awk '{print $1}') | grep Capacity | awk '{print $2}' | rev | cut -d"/" -f1  | rev | sed 's/Gi//g')
echo ${SIZE}

aws ec2 create-snapshot --volume-id ${VOLUME_ID} \
  --description "${PVC_NAME} backup" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=team,Value=DevOps},{Key=name,Value=${PVC_NAME}}]"

snapshot_id=$(aws ec2 describe-snapshots \
    --filters Name=tag:name,Values=${PVC_NAME} \
    --owner-ids self \
    --query "Snapshots[*].{ID:SnapshotId}" \
    --output text)
echo ${snapshot_id}

aws ec2 create-volume \
    --volume-type gp3 \
    --size ${SIZE} \
    --snapshot-id ${snapshot_id} \
    --availability-zone ${SUBNET} \
    --tag-specifications "ResourceType=volume,Tags=[{Key=team,Value=DevOps},{Key=name,Value=${PVC_NAME}}]"

VOLUME_ID=$(aws ec2 describe-volumes \
    --filters Name=tag:name,Values=${PVC_NAME} \
    --query "Volumes[*].{ID:VolumeId}" \
    --output text)
echo ${VOLUME_ID}

cp -Rf copy/pv.yaml copy/pv.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" copy/pv.yaml_bak
sed -i "s/VOLUME_ID/${VOLUME_ID}/g" copy/pv.yaml_bak
sed -i "s/PV_ID/${PV_ID}/g" copy/pv.yaml_bak
sed -i "s/SIZE/${SIZE}/g" copy/pv.yaml_bak

#
kubectl patch pvc ${PVC_NAME} -p '{"metadata":{"finalizers":null}}' -n ${NAMESPACE}
kubectl patch pv ${PV_ID} -p '{"metadata":{"finalizers":null}}'
kubectl delete pv ${PV_ID}

kubectl apply -f copy/pv.yaml_bak -n ${NAMESPACE}



