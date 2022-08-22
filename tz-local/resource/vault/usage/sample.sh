#!/usr/bin/env bash

# https://blog.medinvention.dev/vault-consul-kubernetes-deployment/
# https://github.com/mmohamed/vault-kubernetes
# https://luniverse.io/vault-service-1/?lang=ko

#7- Sample deployment :
mkdir sample
cd sample
curl https://releases.hashicorp.com/vault/1.6.2/vault_1.6.2_linux_amd64.zip -o vault_1.6.2_linux_amd64.zip
unzip vault_1.6.2_linux_amd64.zip
chmod +x vault
sudo mv vault /usr/local/bin/

cd /vagrant/tz-local/resource/vault/nohelm
#http://dooheehong323:31699/ui/vault/nodes/vault-6db4484b8-wx4m4/service-instances
export VAULT_ADDR=http://172.16.84.186:8200
vault status

#7.1- Unseal
k get all -n vault
#pod/vault-6db4484b8-wx4m4
k -n vault exec -ti vault-6db4484b8-wx4m4 -- sh
export VAULT_ADDR=http://localhost:8200
vault operator init

#Unseal Key 1: y6DY7tv72f2OQ0nlvrbB90s8h5zrDu8jk5y9ruM7kRix
#Unseal Key 2: CPpP2zkuanKLQTLsaEE4nn7jjhO5YFRnkjjMSbCtvOYX
#Unseal Key 3: 8UDH3d4sTjeGagT2DiCAxvs2BB/TaB4QlXv3viFEfkSz
#Unseal Key 4: 9uM4CQc/M8iLs1r456FuYOyfsXwtwCObZtjg9y8+sOwl
#Unseal Key 5: q8oQEVyQclD7TZj5oCmJX3MpMx8mS2jbvMgayderjB0F
#
#Initial Root Token: s.IBa4LZiOSsP8wyhhe9YXQKAw

# vault operator unseal
vault operator unseal

vault login s.n0VkXLpWp165y2SzBp4X3KWr

#3. Create key/value for testing
vault secrets enable kv
vault kv put kv/myapp/config username="admin" password="hdh971097"

#4. Connect K8S to Vault
# Create the service account to access secret
kubectl apply -f myapp/service-account.yaml
# Enable kubernetes support
vault auth enable kubernetes
# Prepare kube api server data
export SECRET_NAME="$(kubectl -n vault get serviceaccount vault-auth  -o go-template='{{ (index .secrets 0).name }}')"
export TR_ACCOUNT_TOKEN="$(kubectl -n vault get secret ${SECRET_NAME} -o go-template='{{ .data.token }}' | base64 --decode)"
export K8S_API_SERVER="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"server\" }}{{ end }}")"
export K8S_CACERT="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"certificate-authority-data\" }}{{ end }}" | base64 --decode)"
echo "SECRET_NAME: ${SECRET_NAME}"
echo "TR_ACCOUNT_TOKEN: ${TR_ACCOUNT_TOKEN}"
echo "K8S_API_SERVER: ${K8S_API_SERVER}"
echo "K8S_CACERT: ${K8S_CACERT}"

# Send kube config to vault
vault write auth/kubernetes/config kubernetes_host="${K8S_API_SERVER}" kubernetes_ca_cert="${K8S_CACERT}" token_reviewer_jwt="${TR_ACCOUNT_TOKEN}"

#5. Create Vault policy and role for "myapp"
#myapp/policy.json
#path "kv/myapp/*" {
#  capabilities = ["read", "list"]
#}

#Create the application role
vault policy write myapp-ro myapp/policy.json
vault write auth/kubernetes/role/myapp-role bound_service_account_names=vault-auth bound_service_account_namespaces=vault policies=default,myapp-ro ttl=15m

#6. Deploy "myapp" for testing
#edit admin / password
#vi vault/myapp/deployment.yaml

kubectl apply -f myapp/deployment.yaml
export POD=$(kubectl -n vault get pods --selector=app=myapp --output=jsonpath={.items..metadata.name})
kubectl logs ${POD} myapp -n vault

############################################################
#AWS secret testing
############################################################
vault secrets enable -path=aws aws

vault write aws/config/root \
    access_key=AKIAW354R7YB532NJJMH \
    secret_key=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

vault write aws/roles/my-role \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF

#create secret
vault read aws/creds/my-role
#Key                Value
#---                -----
#lease_id           aws/creds/my-role/7cJAIfwcoDSBitZXKZ1ybGON
#lease_duration     768h
#lease_renewable    true
#access_key         xxxxxx
#secret_key         xxxxx
#security_token     <nil>

#renew secret with lease_id
vault lease renew aws/creds/my-role/7cJAIfwcoDSBitZXKZ1ybGON
#lease_id           aws/creds/my-role/7cJAIfwcoDSBitZXKZ1ybGON
#lease_duration     767h57m50s
#lease_renewable    true

#remove secret
vault lease revoke aws/creds/my-role/7cJAIfwcoDSBitZXKZ1ybGON

############################################################
#MYSQL dynamic sql user creation
############################################################
#https://www.vaultproject.io/docs/secrets/databases/mysql-maria

MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace mysql mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)
#kubectl -n mysql run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il
#apt-get update && apt-get install mysql-client -y
#mysql -h mysql -p

MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
kubectl -n mysql port-forward svc/mysql 3306
mysql -h ${MYSQL_HOST} -P${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD}

#k -n mysql patch svc mysql --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":30306}]'
#sudo apt install mysql-client -y

# add a userpass
echo '
path "database/*" {
  capabilities = ["list", "create", "update", "delete"]
}
' > database1.hcl
vault policy write tz-database database1.hcl

vault policy list
vault auth enable userpass
vault write auth/userpass/users/vaultuser password=hdh971097 policies=default,tz-database
#vault delete auth/userpass/users/vaultuser
#vault list auth/userpass/users
#vault read auth/userpass/users/vaultuser

vault login -method=userpass username=vaultuser

#vault secrets disable database
vault secrets enable database
vault write database/config/my-mysql-database \
    plugin_name=mysql-database-plugin \
    connection_url="root:z5LvE8DUd5@tcp(mysql.mysql.svc.cluster.local:3306)/" \
    allowed_roles="my-role" \
    username="vaultuser" \
    password="hdh971097"

vault write database/roles/my-role \
    db_name=my-mysql-database \
    creation_statements="CREATE USER 'testuser'@'%' IDENTIFIED BY 'testuser_passwd';GRANT SELECT ON *.* TO 'testuser'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"

vault login
#Generate a new credential by reading from the /creds
#vault lease revoke database/creds/my-role/rcqRBCEAaohd6miSCbkX4xcs
vault read database/creds/my-role
#Key                Value
#---                -----
#lease_id           database/creds/my-role/rcqRBCEAaohd6miSCbkX4xcs
#lease_duration     1h
#lease_renewable    true
#password           i-1HucymYJTBUN-4Ttwc
#username           v_root_my-role_PypEp80V6IUyYU7IW

############################################################
# vault token
############################################################
vault auth enable token
vault token create
#Key                  Value
#---                  -----
#token                s.05f5b7czVoDelwez0FNCE7F1
#token_accessor       S7FqQm8O8fEkKoiHcAD7tSXV
#token_duration       ∞
#token_renewable      false
#token_policies       ["root"]
#identity_policies    []
#policies             ["root"]

vault login s.05f5b7czVoDelwez0FNCE7F1

vault token revoke s.05f5b7czVoDelwez0FNCE7F1

############################################################
# vault github
############################################################
#register a new token (tz-vault) in here
#https://github.com/settings/tokens

echo '
path "secret/*" {
  capabilities = ["create"]
}
path "secret/foo" {
  capabilities = ["read"]
}

# Dev servers have version 2 of KV mounted by default, so will need these
# paths:
path "secret/data/*" {
  capabilities = ["create"]
}
path "secret/data/foo" {
  capabilities = ["read"]
}
' > my-policy1.hcl

vault login s.n0VkXLpWp165y2SzBp4X3KWr
vault policy write my-policy my-policy1.hcl
vault policy read my-policy

vault auth enable -path=github github
#vault lease revoke auth/github/config
vault write auth/github/config organization=tz-project
#vault lease revoke auth/github/map/teams/tz-project
vault write auth/github/map/teams/tz-project value=default,my-policy
vault auth list
vault login -method=github token=xxxxxxxgithubxxxxx

vault login s.n0VkXLpWp165y2SzBp4X3KWr
vault token create -policy=my-policy
#Key                  Value
#---                  -----
#token                s.VGw3BsjYGtI84oJ0g3LTDTwl
vault login s.VGw3BsjYGtI84oJ0g3LTDTwl



exit 0

apt update && apt install curl dnsutils iputils-ping unzip -y
curl https://releases.hashicorp.com/vault/1.6.2/vault_1.6.2_linux_amd64.zip -o vault_1.6.2_linux_amd64.zip
unzip vault_1.6.2_linux_amd64.zip
chmod +x vault
mv vault /usr/local/bin/

export VAULT_ADDR=http://vault-internal.vault.svc.cluster.local:8200
export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
vault login doohee.hong



