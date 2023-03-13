#!/usr/bin/env bash

#cd /Volumes/workspace/tz/tz-eks-main-s/tz-local/docker
#set -x

eks_project=${eks_project}
eks_domain=${eks_domain}
secret_name=${secret_name}
bucket_name=devops-prod
source_name=resources

if [ "${eks_project}" == "" ]; then
  eks_project=eks-main-s
fi
if [ "${eks_domain}" == "" ]; then
  eks_domain=t1zone.net
fi
if [ "${secret_name}" == "" ]; then
  secret_name=devops-utils
fi

#cd /vagrant

if [ "$1" == "help" ]; then
  echo "##[help] #########################################################################################"
  echo " export vault_token=xxxxxxxxxx"
  echo " bash /vagrant/tz-local/docker/vault.sh put devops-prod devops-utils resources"
  echo " bash /vagrant/tz-local/docker/vault.sh get devops-prod devops-utils"
  echo " bash /vagrant/tz-local/docker/vault.sh delete devops-prod devops-utils"
  echo " bash /vagrant/tz-local/docker/vault.sh fput tgd-dev tz-partners_pk.pem pk.pem"
  echo " bash /vagrant/tz-local/docker/vault.sh fget tgd-dev tz-partners_pk.pem"
  echo "##################################################################################################"
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
secret_name=$3

if [ "${vault_token}" == "" ]; then
  echo "vault_token is required in ENV!"
  exit 1
fi

export VAULT_ADDR=https://vault.${eks_domain}
vault login ${vault_token}

echo "eks_project: ${eks_project}"
echo "eks_domain: ${eks_domain}"
echo "bucket_name: ${bucket_name}"
echo "secret_name: ${secret_name}"

if [[ "$1" == "put" || "$1" == "fput" ]]; then
  if [ "$2" == "" ]; then
    echo "$0 $1 $2"
    exit 1
  fi

  if [ "$4" == "" ]; then
    echo "$0 $1 $2 $3 $4"
    exit 1
  fi
  source_name=$4
  echo "source_name: ${source_name}"

  echo '{
    "data": {
      "resources":"BFILE"
    }
  }' > payload.json

  if [ "$1" == "put" ]; then
    tar cvfz resources.zip ${source_name}
    BFILE=$(openssl base64 -A -in resources.zip)
    #  BFILE=$(cat resources.zip | base64)
    rm -Rf resources.zip
  elif [ "$1" == "fput" ]; then
    BFILE=$(openssl base64 -A -in ${source_name})
  fi
  cat payload.json | sed "s|BFILE|${BFILE}|g" > payload2.json
  rm -Rf payload.json

  curl \
      --header "X-Vault-Token: ${vault_token}" \
      --request POST \
      --data @payload2.json \
      "https://vault.${eks_domain}/v1/secret/data/${bucket_name}/${secret_name}"
  rm -Rf payload2.json
elif [[ "$1" == "get" || "$1" == "fget" ]]; then
  echo "https://vault.${eks_domain}/v1/secret/data/${bucket_name}/${secret_name}"
  curl \
      --header "X-Vault-Token: ${vault_token}" \
      "https://vault.${eks_domain}/v1/secret/data/${bucket_name}/${secret_name}" | jq '.data | map(.resources)[0]' \
      | sed -e 's|"||g' > payload3.json
  if [ "$1" == "get" ]; then
    cat payload3.json | base64 -d > ${source_name}.zip
  elif [ "$1" == "fget" ]; then
    cat payload3.json | base64 -d > ${source_name}
    cat ${source_name}
    rm -Rf ${source_name}
  fi
  rm -Rf payload3.json
elif [ "$1" == "delete" ]; then
  curl \
      --header "X-Vault-Token: ${vault_token}" \
      --request DELETE \
      "https://vault.${eks_domain}/v1/secret/data/${bucket_name}/${secret_name}"
fi

