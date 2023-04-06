#!/usr/bin/env bash

export AWS_PROFILE=default

aws sts get-caller-identity
aws-vault add default aws-vault list

#https://medium.com/modusign/terraform-aws-%EC%85%8B%ED%8C%85%ED%95%98%EA%B8%B0-part-1-a3dae9f5fbbd

cd /vagrant/terraform-aws-iam/workspace/dev

terraform init
terraform apply -auto-approve
#terraform destroy -auto-approve



#wget https://github.com/99designs/aws-vault/releases/download/v6.3.1/aws-vault-linux-amd64
#sudo mv aws-vault-linux-amd64 /usr/sbin/aws-vault
#sudo chmod 777 /usr/sbin/aws-vault
#aws-vault --version

#brew install awscli
#brew install aws-vault --cask
aws-vault add default
aws-vault ls

aws-vault exec default -- aws sts get-caller-identity
aws-vault exec default --debug -- aws s3 ls
#aws-vault exec default -- grep AWS

aws-vault exec default -- terraform plan

#[profile default]
#region = us-west-1
#
#[profile default_admin_role]
#source_profile=default
#role_arn=arn:aws:iam::472304975363:role/admin

aws-vault exec default_admin_role -- aws s3 ls


exit 0




