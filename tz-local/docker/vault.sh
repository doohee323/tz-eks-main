#!/usr/bin/env bash

#cd /Volumes/workspace/tz/tz-eks-main-p/tz-local/docker
#set -x

eks_project=${eks_project}
eks_domain=${eks_domain}
tz_project=${tz_project}
bucket_name=devops-prod
folder_name=resources

#eks_project=eks-main-p
#eks_domain=tzcorp.com
#tz_project=eks-main-p

cd /vagrant

if [ "$1" == "help" ]; then
  echo "##[help] ########################################"
  echo " export vault_token=xxxxxxxxxx"
  echo " bash /vagrant/tz-local/docker/vault.sh put devops-prod devops-utils resources"
  echo " bash /vagrant/tz-local/docker/vault.sh get devops-prod devops-utils resources"
  echo " bash /vagrant/tz-local/docker/vault.sh delete devops-prod devops-utils resources"
  echo "#################################################"
  exit 0
fi

if [ "$2" == "" ]; then
  echo "$0 $1 $2 $3"
  exit 1
fi
bucket_name=$2

if [ "$3" == "" ]; then
  echo "$0 $1 $2 $3 $4"
  exit 1
fi
tz_project=$3

if [ "$4" == "" ]; then
  echo "$0 $1 $2 $3 $4"
  exit 1
fi
folder_name=$4

export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login ${vault_token}

echo "eks_project: ${eks_project}"
echo "eks_domain: ${eks_domain}"
echo "tz_project: ${tz_project}"
echo "bucket_name: ${bucket_name}"
echo "folder_name: ${folder_name}"

if [ "$1" == "put" ]; then
  if [ "$2" == "" ]; then
    echo "$0 $1 $2"
    exit 1
  fi

  echo '{
    "data": {
      "resources":"BFILE"
    }
  }' > payload.json

  tar cvfz resources.zip ${folder_name}
  BFILE=$(openssl base64 -A -in resources.zip)
#  BFILE=$(cat resources.zip | base64)
  rm -Rf resources.zip
  cat payload.json | sed "s|BFILE|${BFILE}|g" > payload2.json
  rm -Rf payload.json

  curl \
      --header "X-Vault-Token: ${vault_token}" \
      --request POST \
      --data @payload2.json \
      "http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/${bucket_name}/${tz_project}"
  rm -Rf payload2.json

elif [ "$1" == "get" ]; then
  echo "http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/${bucket_name}/${tz_project}"
  curl \
      --header "X-Vault-Token: ${vault_token}" \
      "http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/${bucket_name}/${tz_project}" | jq '.data | map(.resources)[0]' \
      | sed -e 's|"||g' > payload3.json

  cat payload3.json | base64 -d > ${folder_name}.zip
  rm -Rf payload3.json
elif [ "$1" == "delete" ]; then
  curl \
      --header "X-Vault-Token: ${vault_token}" \
      --request DELETE \
      "http://vault.default.${eks_project}.${eks_domain}/v1/secret/data/${bucket_name}/${tz_project}"
fi

