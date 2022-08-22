#!/usr/bin/env bash

#bash /vagrant/tz-local/resource/ses/install.sh
cd /vagrant/tz-local/resource/ses

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
NS=extension-dev

# 1. make ubuntu pod as bastion
kubectl -n extension-dev apply -f ubuntu.yaml

# 2. upload aws, k8s credentials
kubectl -n extension-dev cp /home/vagrant/.aws extension-dev/bastion:/root/.aws
kubectl -n extension-dev cp /home/vagrant/.kube extension-dev/bastion:/root/.kube
kubectl -n extension-dev cp /home/vagrant/.ssh extension-dev/bastion:/root/.ssh

# 4. install utils in bastion
kubectl -n extension-dev exec -it bastion -- sh

apt-get update -y
apt-get install -y curl wget awscli jq unzip netcat apt-transport-https gnupg2

curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/aws-iam-authenticator
chmod +x aws-iam-authenticator
mv aws-iam-authenticator /usr/local/bin

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl

export AWS_ACCESS_KEY_ID=xxxxxx
export AWS_SECRET_ACCESS_KEY=xxxxxx
export AWS_REGION=ap-northeast-2

kubectl cp destination.json extension-dev/bastion:destination.json
kubectl cp message.json extension-dev/bastion:message.json
aws ses send-email --from devops@tz.com --destination file://destination.json --message file://message.json

# destination.json
{
  "ToAddresses":  ["topzone-dev@tz.com"],
  "CcAddresses":  ["devops@tz.com"],
  "BccAddresses": []
}

