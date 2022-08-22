#!/usr/bin/env bash

#set -x

#bash /vagrant/tz-local/resource/vault/data/vault_user.sh
cd /vagrant/tz-local/resource/vault/data

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
vault_token=$(prop 'project' 'vault')

export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
echo ${VAULT_ADDR}
vault login ${vault_token}

vault secrets enable aws
vault secrets enable consul
vault auth enable kubernetes
vault secrets enable database
vault secrets enable pki
vault secrets enable -version=2 kv
vault secrets enable kv-v2
vault kv enable-versioning secret/
vault secrets enable -path=kv kv
vault secrets enable -path=secret/ kv
vault auth enable userpass

vault kv enable-versioning secret/

userpass_accessor="$(vault auth list | awk '/^userpass/ {print $3}')"
cp userpass.hcl userpass.hcl_bak
sed -i "s/userpass_accessor/${userpass_accessor}/g" userpass.hcl_bak
vault policy write tz-vault-userpass /vagrant/tz-local/resource/vault/data/userpass.hcl_bak

PROJECTS=($(kubectl get namespaces | awk '{print $1}' | tr '\n' ' '))
#PROJECTS=(devops-dev devops-prod)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    if [[ "${item/*-dev/}" == "" ]]; then
      project=${item/-prod/}
      echo "=====================dev"
    else
      project=${item}-prod
      echo "=====================prod"
    fi
    echo "/vagrant/tz-local/resource/vault/data/${project}.hcl"
    if [[ -f /vagrant/tz-local/resource/vault/data/${project}.hcl ]]; then
      echo ${item} : ${item/*-dev/}
      echo project: ${project}
      echo role: auth/kubernetes/role/${project}
      echo policy: tz-vault-${project}
      echo svcaccount: ${item}-svcaccount
      vault policy write tz-vault-${project} /vagrant/tz-local/resource/vault/data/${project}.hcl
      vault write auth/kubernetes/role/${project} \
              bound_service_account_names=${item}-svcaccount \
              bound_service_account_namespaces=${item} \
              policies=tz-vault-${project} \
              ttl=24h
    fi
  fi
done

# set a secret engine
vault secrets list
vault secrets list -detailed

# add a userpass
#vault write auth/userpass/users/adminuser password=adminuser policies=tz-vault-devops-dev,tz-vault-devops-prod,tz-vault-userpass
#vault write auth/userpass/users/adminuser password=adminuser policies=tz-vault-devops-dev,tz-vault-devops-prod,tz-vault-userpass
#vault write auth/userpass/users/doohee.hong password=doohee.hong policies=tz-vault-devops-dev,tz-vault-devops-prod,tz-vault-userpass
#vault write auth/userpass/users/doogee.hong password=doogee.hong policies=tz-vault-devops-dev,tz-vault-userpass
#vault write auth/userpass/users/jeonghee.kang password=jeonghee.kang policies=tz-vault-devops-dev,tz-vault-devops-prod,tz-vault-userpass
#vault write auth/userpass/users/ec.song password=ec.song policies=read-role,tz-vault-datateam-dev,tz-vault-datateam-prod,tz-vault-userpass
#vault write auth/userpass/users/sh.han password=sh.han policies=tz-vault-gocre-dev,tz-vault-gocre-prod,tz-vault-userpass
#vault write auth/userpass/users/spex password=spex policies=tz-vault-gocre-dev,tz-vault-gocre-prod,tz-vault-userpass
#vault write auth/userpass/users/sm.ku password=sm.ku policies=tz-vault-datateam-dev,tz-vault-datateam-prod,tz-vault-userpass
#vault write auth/userpass/users/hj.jeon password=hj.jeon policies=tz-vault-datateam-dev,tz-vault-datateam-prod,tz-vault-userpass

#vault policy write tz-vault-datateam-dev /vagrant/tz-local/resource/vault/data/datateam-dev.hcl

vault write auth/kubernetes/role/datateam-dev \
        bound_service_account_names=* \
        bound_service_account_namespaces=datateam-dev \
        policies=tz-vault-datateam-dev \
        ttl=24h
vault read auth/kubernetes/role/datateam-dev

vault kv put secret/devops-dev/dbinfo db_id=value1 db_password=value2
vault kv put secret/devops-dev/foo db_id2=value1 db_password2=value2

vault write auth/kubernetes/role/datateam-prod \
        bound_service_account_names=* \
        bound_service_account_namespaces=datateam-prod \
        policies=tz-vault-datateam-prod \
        ttl=24h

exit 0

brew tap hashicorp/tap
brew install hashicorp/tap/vault
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login -method=userpass username=jeonghee.kang
vault write auth/userpass/users/jeonghee.kang password=XXXXX
vault kv put secret/devops/database type=mysql name=testdb host=localhost port=2222 passwod=1111 ttl='30s'
vault kv get secret/devops/database



export new_token=$(vault token create -policy=tz-vault-devops-prod | grep token | head -n 1 | awk '{print $2}')
export new_token=s.pMoZ0JmzSd2K4espkjVqF4mF
export VAULT_ADDR=https://vault.default.eks-main.tzcorp.com

vault kv put secret/devops-prod/dbinfo passwod=22222 name=local.tzcorp.com
vault kv get secret/devops-prod/dbinfo
vault kv get -field=passwod secret/devops-prod/dbinfo

vault token create -policy=tz-vault-devops-prod -display-name=devops-prod
vault token create -policy=tz-vault-devops-prod -display-name=devops-prod2
vault token lookup s.c18WG47cH8APgPHSYyzwbZN1
vault token create -policy=tz-vault-devops-prod -display-name=devops-prod2 -period=768h
vault token lookup s.M2wXy9ntL1pjHdkvVipb9nLB

vault list auth/token/accessors
vault token revoke s.PnKJ81rRniGZRTb8nGBN8MR4
vault token lookup s.PnKJ81rRniGZRTb8nGBN8MR4
vault token lookup -accessor oSvjusacB5mFueA89bS7aJ2N
vault token revoke -accessor 8Pzl4FACUmJMizlHNJi25AWF

s.sZJ2S9Bt92iCLsOCm47MeGcy / oSvjusacB5mFueA89bS7aJ2N




