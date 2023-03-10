#!/usr/bin/env bash

# sudo bash /vagrant/scripts/eks_install.sh
cd /vagrant/scripts

rm -Rf /vagrant/info

export AWS_PROFILE=default
function propProject {
	grep "${1}" "/vagrant/resources/project" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
export eks_project=$(propProject 'project')
export aws_account_id=$(propProject 'aws_account_id')
PROJECT_BASE='/vagrant/terraform-aws-eks/workspace/base'

function propConfig {
  grep "${1}" "/vagrant/resources/config" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
aws_region=$(propConfig 'region')
export AWS_DEFAULT_REGION="${aws_region}"

echo "eks_project: ${eks_project}"
echo "aws_region: ${aws_region}"
echo "aws_account_id: ${aws_account_id}"

echo "
export AWS_DEFAULT_REGION=${aws_region}
alias k='kubectl'
alias KUBECONFIG='~/.kube/config'
alias base='cd /vagrant/terraform-aws-eks/workspace/base'
alias scripts='cd /vagrant/scripts'
alias tplan='terraform plan -var-file=.auto.tfvars'
alias tapply='terraform apply -var-file=.auto.tfvars -auto-approve'
" >> /home/vagrant/.bashrc

source /home/vagrant/.bashrc
echo "
export AWS_DEFAULT_REGION=${aws_region}
alias k='kubectl'
alias KUBECONFIG='~/.kube/config'
alias base='cd /vagrant/terraform-aws-eks/workspace/base'
alias scripts='cd /vagrant/scripts'
alias tplan='terraform plan -var-file=.auto.tfvars'
alias tapply='terraform apply -var-file=.auto.tfvars -auto-approve'
" >> /root/.bashrc

INSTALL_INIT="$(aws eks describe-cluster --name ${eks_project} | grep ${eks_project})"
echo "INSTALL_INIT:"$INSTALL_INIT
if [[ "${INSTALL_INIT}" == "" ]]; then
  INSTALL_INIT='true'
  bash /vagrant/scripts/eks_remove_all.sh cleanTfFiles
fi

if [[ "${INSTALL_INIT}" == 'true' || ! -f "/home/vagrant/.aws/config" ]]; then
  sudo service systemd-resolved stop
  sudo systemctl disable systemd-resolved
  sudo rm -Rf /etc/resolv.conf

cat <<EOF > /etc/resolv.conf
nameserver 1.1.1.1 #cloudflare DNS
nameserver 8.8.8.8 #Google DNS
EOF

  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update -y
  sudo apt purge terraform -y
  sudo apt install terraform=1.1.7
  terraform -v
  sudo apt install awscli jq unzip -y
  sudo apt install ntp -y
  sudo systemctl enable ntp

  wget "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
  tar xvfz "eksctl_$(uname -s)_amd64.tar.gz"
  rm -Rf "eksctl_$(uname -s)_amd64.tar.gz"
  sudo mv eksctl /usr/local/bin

  curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
  chmod +x aws-iam-authenticator
  mv aws-iam-authenticator /usr/local/bin
  /usr/local/bin/aws-iam-authenticator version

  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  rm -Rf awscliv2.zip
  sudo ./aws/install
  rm -Rf ~/.aws/cli/cache

  echo "## [ install helm3 ] ######################################################"
  curl -L https://git.io/get_helm.sh | bash -s -- --version v3.8.2
  sudo rm -Rf get_helm.sh
  sleep 10
  helm repo add stable https://charts.helm.sh/stable
  helm repo update

  sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update

  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl
  chmod 777 kubectl
  sudo mv kubectl /usr/bin/kubectl

  wget https://releases.hashicorp.com/consul/1.8.4/consul_1.8.4_linux_amd64.zip
  unzip consul_1.8.4_linux_amd64.zip
  rm -Rf consul_1.8.4_linux_amd64.zip
  sudo mv consul /usr/local/bin/

  wget https://releases.hashicorp.com/vault/1.3.1/vault_1.3.1_linux_amd64.zip
  unzip vault_1.3.1_linux_amd64.zip
  rm -Rf vault_1.3.1_linux_amd64.zip
  sudo mv vault /usr/local/bin/
  vault -autocomplete-install
  complete -C /usr/local/bin/vault vault

  curl -L -o kubectl-cert-manager.tar.gz https://github.com/jetstack/cert-manager/releases/latest/download/kubectl-cert_manager-linux-amd64.tar.gz
  tar xzf kubectl-cert-manager.tar.gz
  rm -Rf kubectl-cert-manager.tar.gz
  rm -Rf LICENSES
  sudo mv kubectl-cert_manager /usr/local/bin

  VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
  sudo chmod +x /usr/local/bin/argocd
fi

sudo mkdir -p /home/vagrant/.aws
sudo cp -Rf /vagrant/resources/config /home/vagrant/.aws/config
sudo cp -Rf /vagrant/resources/credentials /home/vagrant/.aws/credentials
sudo cp -Rf /vagrant/resources/project /home/vagrant/.aws/project
sudo chown -Rf vagrant:vagrant /home/vagrant/.aws
sudo rm -Rf /root/.aws
sudo cp -Rf /home/vagrant/.aws /root/.aws

cd ${PROJECT_BASE}
if [ ! -f "${PROJECT_BASE}/terraform.tfstate" ]; then
  # make aws credentials
  rm -Rf ${eks_project}*
  ssh-keygen -t rsa -C ${eks_project} -P "" -f ${eks_project} -q
  chmod -Rf 600 ${eks_project}*
  cp -Rf ${eks_project}* /home/vagrant/.ssh
  cp -Rf ${eks_project}* /vagrant/resources
  chown -Rf vagrant:vagrant /home/vagrant/.ssh
  chown -Rf vagrant:vagrant /vagrant/resources

  rm -Rf ${PROJECT_BASE}/lb2.tf

  terraform init
  terraform plan -var-file=".auto.tfvars"
#  terraform plan | sed 's/\x1b\[[0-9;]*m//g' > a.txt
  terraform apply -var-file=".auto.tfvars" -auto-approve

  export KUBECONFIG=`ls kubeconfig_${eks_project}*`
  cp -Rf $KUBECONFIG /vagrant/config_${eks_project}
  sudo mkdir -p /root/.kube
  sudo cp -Rf $KUBECONFIG /root/.kube/config
  sudo chmod -Rf 600 /root/.kube/config
  mkdir -p /home/vagrant/.kube
  cp -Rf $KUBECONFIG /home/vagrant/.kube/config
  sudo chmod -Rf 600 /home/vagrant/.kube/config
  export KUBECONFIG=/home/vagrant/.kube/config
  sudo chown -Rf vagrant:vagrant /home/vagrant

  cp -Rf lb2.tf_ori lb2.tf

  terraform init
  terraform plan -var-file=".auto.tfvars"
  terraform apply -var-file=".auto.tfvars" -auto-approve
fi

bash /vagrant/scripts/eks_addtion.sh

echo "
##[ Summary ]##########################################################
  - in VM
    export KUBECONFIG='/vagrant/config_${eks_project}'

  - outside of VM
    export KUBECONFIG='terraform-aws-eks/workspace/base/kubeconfig_${eks_project}'

  - kubectl get nodes
  - S3 bucket: ${s3_bucket_id}
#######################################################################
" > /vagrant/info
cat /vagrant/info

exit 0
