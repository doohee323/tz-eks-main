#https://aws.amazon.com/ko/premiumsupport/knowledge-center/eks-persistent-storage/

cd /vagrant/tz-local/resource/persistent-storage

AWS_REGION=$(prop 'config' 'region')
eks_project=$(prop 'project' 'project')
aws_account_id=$(aws sts get-caller-identity --query Account --output text)

VOLUME_ID=$(aws ec2 create-volume \
    --region ${AWS_REGION} \
    --availability-zone ${AWS_REGION}c \
    --volume-type gp2 \
    --size 1 | grep VolumeId | awk '{print $2}' | sed 's/\"//g;s/\,//g')
echo ${VOLUME_ID}
#aws ec2 delete-volume --volume-id ${VOLUME_ID}

cp -Rf exist/claim.yaml exist/claim.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" exist/claim.yaml_bak
sed -i "s/VOLUME_ID/${VOLUME_ID}/g" exist/claim.yaml_bak

kubectl apply -f exist/claim.yaml_bak
kubectl apply -f exist/pod.yaml
kubectl describe storageclass ebs-sc
#kubectl get pods --watch
sleep 30

kubectl describe pv $(kubectl get pv | grep ebs-claim | awk '{print $1}')
kubectl exec -it test-app -- cat /data/out.txt
kubectl delete -f exist/pod.yaml

kubectl apply -f exist/pod2.yaml
kubectl exec -it test-app2 -- cat /data/out.txt



