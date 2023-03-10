#!/bin/bash

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y
sudo apt purge terraform -y
#sudo apt install terraform
sudo apt install terraform=0.13.6
terraform -v
sudo apt install jq unzip -y

wget "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
tar xvfz "eksctl_$(uname -s)_amd64.tar.gz"
rm -Rf "eksctl_$(uname -s)_amd64.tar.gz"
sudo mv eksctl /usr/local/bin

curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
chmod +x aws-iam-authenticator
mv aws-iam-authenticator /usr/local/bin
#/usr/local/bin/aws-iam-authenticator version

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo "## [ install helm3 ] ######################################################"
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
sudo bash get_helm.sh
sudo rm -Rf get_helm.sh
sleep 10
helm repo add stable https://charts.helm.sh/stable
helm repo update

sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

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

sudo apt-get update && sudo apt-get install mysql-client -y

#bash /home/ubuntu/resources/ebs.sh
#mv /home/ubuntu/resources/a.zip /opt/bastion
#cd /opt/bastion
#tar xvfz a.zip | grep *.cvs | xargs -n1 -i mv {} a.cvs


sudo apt-get install -y docker.io apt-transport-https jq docker-compose
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "group": "root"
}
EOF

sudo usermod -G docker ubuntu
sudo chown -Rf ubuntu:ubuntu /var/run/docker.sock
mkdir -p ~/.docker
sudo service docker restart
sudo systemctl enable docker

git clone https://github.com/tzkr/tz-mcall.git
cd tz-mcall
git checkout -b external origin/external

cd docker
docker-compose -f docker-compose.yaml build --no-cache
docker-compose -f docker-compose.yaml up -d

exit 0

