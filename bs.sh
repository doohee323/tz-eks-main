#!/bin/bash

if [[ "$1" == "remove" ]]; then
  bash eks_remove_all.sh
  exit 0
fi

cd tz-local/docker
bash install.sh

export tz_project=eks-main-s
#docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` bash
docker exec -it `docker ps | grep devops-utils-1 | awk '{print $1}'` \
    bash /vagrant/tz-local/docker/init2.sh

exit 0

creating IAM Group eks-main-s-k8sAdmin: EntityAlreadyExists
creating IAM Policy eks-main-s-k8sAdmin: EntityAlreadyExists
creating IAM Role (eks-main-s-k8sAdmin)
creating IAM User (eks-main-s-k8sAdmin): Ent
creating IAM Group eks-main-s-k8sDev: EntityAl
creating IAM Policy eks-main-s-k8sDev: EntityAlreadyExists:
creating IAM Role (eks-main-s-k8sDev): EntityAlreadyExists: R
creating IAM User (eks-main-s-k8sDev): EntityAlreadyExists: User wi
creating IAM Policy eks-main-s-cert-manager-policy: Enti
importing EC2 Key Pair (eks-main-s): InvalidKeyPair.Duplicate
creating KMS Alias (alias/eks-main-s-vault-kms-unseal):
Amazon DynamoDB Table (terraform-eks-main-s-lock-2):
creating KMS Alias (alias/eks/eks-main-s):
creating IAM Policy eks-main-s-ses-policy

creating IAM Policy eks-main-s-ecr-policy:
creating IAM Policy eks-main-s-es-s3-policy

