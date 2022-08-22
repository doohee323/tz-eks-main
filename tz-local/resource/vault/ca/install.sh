#!/usr/bin/env bash

#https://m.blog.naver.com/alice_k106/221803861645
#https://www.vaultproject.io/docs/secrets/ssh/signed-ssh-certificates

#bash /vagrant/tz-local/resource/vault/ca/install.sh
cd /vagrant/tz-local/resource/vault/ca

sudo su

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
AWS_REGION=$(prop 'config' 'region')
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id')
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key')
vault_kms_key=$(aws kms list-aliases | grep ${eks_project}-vault-kms-unseal -A 1 | tail -n 1 | awk -F\" '{print $4}')
vault_token=$(prop 'project' 'vault')
#export VAULT_TOKEN=${vault_token}
NS=vault

export VAULT_ADDR="http://vault.default.${eks_project}.${eks_domain}"
echo "VAULT_ADDR: ${VAULT_ADDR}"
vault login ${vault_token}
#export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
#vault login s.1pVzz8zXNCfdjegj0cfrkdDT

vault secrets enable -path=ssh-client-signer ssh
vault write ssh-client-signer/config/ca generate_signing_key=true

########################################################
# Signing Key & Role Configuration
########################################################
#curl -o /etc/ssh/trusted-user-ca-keys.pem ${VAULT_ADDR}/v1/ssh-client-signer/public_key
#sudo touch /etc/ssh/trusted-user-ca-keys.pem
#sudo chown -Rf vagrant:vagrant /etc/ssh/trusted-user-ca-keys.pem
#curl -o /etc/ssh/trusted-user-ca-keys.pem ${VAULT_ADDR}/v1/ssh-client-signer/public_key
vault read -field=public_key ssh-client-signer/config/ca > /etc/ssh/trusted-user-ca-keys.pem
echo 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' | sudo tee -a /etc/ssh/sshd_config
sudo service ssh restart

vault write ssh-client-signer/roles/my-role -<<"EOH"
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": [
    {
      "permit-pty": ""
    }
  ],
  "key_type": "ca",
  "default_user": "root",
  "ttl": "300m0s"
}
EOH

vault write ssh-client-signer/roles/one_minute -<<"EOH"
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": [
    {
      "permit-pty": ""
    }
  ],
  "key_type": "ca",
  "default_user": "root",
  "ttl": "1m0s"
}
EOH

vault policy write require-ssh-sign sign-policy.tf
export server_token_one_minute=$(vault token create -policy=ssh-pubkey-read | grep token | head -n 1 | awk '{print $2}')
vault policy write ssh-pubkey-read policy.tf
export client_token_one_minute=$(vault token create -policy=require-ssh-sign | grep token | head -n 1 | awk '{print $2}')

echo "server_token_one_minute: ${server_token_one_minute}"
echo "client_token_one_minute: ${client_token_one_minute}"
#server_token_one_minute: s.edJUhZJRHKFZ6E1O060x4CS1
#client_token_one_minute: s.88AG0NO4o0aVKLMEkl7inVe0

########################################################
# On ssh server in docker
########################################################
docker rm -f $(docker ps -aq) >/dev/null 2>&1 || true
docker rmi $(docker images -q)

docker network create ssh
#docker run -d -it --name auth-server -h auth-server --net ssh alicek106/vault-ssh-test:latest
docker run -d -it --name ssh-server -h ssh-server --net ssh alicek106/vault-ssh-test:latest
docker run -d -it --name ssh-client -h ssh-client --net ssh alicek106/vault-ssh-test:latest

docker run -d -it --name ssh-server2 -h ssh-server2 --net ssh alicek106/vault-ssh-test:latest
docker run -d -it --name ssh-client2 -h ssh-client2 --net ssh alicek106/vault-ssh-test:latest

#docker ps
#CONTAINER ID   IMAGE                             COMMAND       CREATED         STATUS         PORTS     NAMES
#058edb86b817   alicek106/vault-ssh-test:latest   "/bin/bash"   8 seconds ago   Up 7 seconds             ssh-server2
#59a09029a07d   alicek106/vault-ssh-test:latest   "/bin/bash"   2 minutes ago   Up 2 minutes             ssh-client2
#19aa9b413706   alicek106/vault-ssh-test:latest   "/bin/bash"   6 minutes ago   Up 6 minutes             ssh-server
#a10f41646680   alicek106/vault-ssh-test:latest   "/bin/bash"   6 minutes ago   Up 6 minutes             ssh-client

docker exec -it ssh-server sh
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
export VAULT_TOKEN=s.zzzzzzzzz   # server_token_one_minute
/vault read -field=public_key ssh-client-signer/config/ca > /etc/ssh/trusted-user-ca-keys.pem
echo 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' | tee -a /etc/ssh/sshd_config
service ssh restart

########################################################
# On ssh client in docker
########################################################
docker exec -it ssh-client sh
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
export VAULT_TOKEN=s.zzzzzzzzz    # client_token_one_minute
ssh-keygen
# Ask Vault to sign your public key
/vault write ssh-client-signer/sign/one_minute \
  public_key=@/root/.ssh/id_rsa.pub

# Save the resulting signed, public key to disk
mkdir -p /root/.ssh
/vault write -field=signed_key ssh-client-signer/sign/one_minute \
  public_key=@/root/.ssh/id_rsa.pub > /root/.ssh/id_rsa-cert.pub

ssh ssh-server

########################################################
# On ssh server in Jenkins
########################################################

ssh -i /vagrant/terraform-aws-ec2/workspace/base/devops-utils ubuntu@52.78.63.52
sudo su
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
export VAULT_TOKEN=s.xxxxxxxxx   # server_token_one_minute
vault read -field=public_key ssh-client-signer/config/ca > /etc/ssh/trusted-user-ca-keys.pem
echo 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' | tee -a /etc/ssh/sshd_config
service ssh restart

########################################################
# On ssh client in vagrant
########################################################
ssh-keygen
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
export VAULT_TOKEN=s.zzzzzzzzz    # client_token_my_role
vault write ssh-client-signer/sign/one_minute \
  public_key=@/root/.ssh/id_rsa.pub

mkdir -p /root/.ssh
vault write -field=signed_key ssh-client-signer/sign/one_minute \
  public_key=@/root/.ssh/id_rsa.pub > /root/.ssh/id_rsa-cert.pub

ssh 52.78.63.52

########################################################
# On ssh client in k8s
########################################################
kubectl -n default run -it ssh-client --image=linuxserver/openssh-server -- sh
#kubectl -n default exec -it ssh-client -- sh
apk update && apk add --no-cache vault libcap
setcap cap_ipc_lock= /usr/sbin/vault
ssh-keygen
export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
export VAULT_TOKEN=s.zzzzzzzzz    # client_token_one_minute
vault write ssh-client-signer/sign/one_minute \
  public_key=@/root/.ssh/id_rsa.pub

vault write -field=signed_key ssh-client-signer/sign/one_minute \
  public_key=@/root/.ssh/id_rsa.pub > /root/.ssh/id_rsa-cert.pub

ssh 52.78.63.52
