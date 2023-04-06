#!/usr/bin/env bash

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
TZ_PROJECT=$(prop 'project' 'project')
AWS_REGION=$(prop 'config' 'region')
PROJECT_BASE="/vagrant/terraform-aws-eks/workspace/base"
cd ${PROJECT_BASE}

# restore from other region's s3
#TZ_PROJECT=devops-utils
#AWS_REGION=ap-northeast-1

CMD=$1
if [[ "${CMD}" == "" ]]; then
  echo "No command!"
  echo "bash backup_s3.sh backup or bash backup_s3.sh restore"
  exit 1
fi

S3_BUCKET=$(cat s3_bucket_id)
if [[ "${TZ_PROJECT}" == "" || "${AWS_REGION}" == "" || "${S3_BUCKET}" == "" ]]; then
  echo "No TZ_PROJECT or AWS_REGION or S3_BUCKET!"
  exit 1
fi

BACKUPFILE=$2
if [[ "${BACKUPFILE}" == "" ]]; then
  BACKUPFILE="terraform-tfstate.zip"
fi

if [[ "${CMD}" == "backup" ]]; then
  rm -Rf terraform-tfstate
  mkdir -p terraform-tfstate
  cp -Rf .terraform terraform.tfstate terraform.tfstate.backup terraform-tfstate
  tar cvfz ${BACKUPFILE} terraform-tfstate
  aws s3 cp ${BACKUPFILE} s3://${S3_BUCKET}/${BACKUPFILE} --region ${AWS_REGION}
  echo aws s3 cp ${BACKUPFILE} s3://${S3_BUCKET}/${BACKUPFILE} --region ${AWS_REGION}
  rm -Rf terraform-tfstate ${BACKUPFILE}
elif [[ "${CMD}" == "restore" ]]; then
  mkdir -p terraform-tfstate
  aws s3 cp s3://${S3_BUCKET}/${BACKUPFILE} terraform-tfstate/${BACKUPFILE} --region ${AWS_REGION}
  echo tar xvfz terraform-tfstate/${BACKUPFILE}
  tar xvfz terraform-tfstate/${BACKUPFILE}
  rm -Rf terraform-tfstate/${BACKUPFILE}
  rm -Rf .terraform terraform.tfstate terraform.tfstate.backup
  mv terraform-tfstate/* .
  mv terraform-tfstate/.* .
  rm -Rf terraform-tfstate
fi

