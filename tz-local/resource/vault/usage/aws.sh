#!/usr/bin/env bash

### https://lejewk.github.io/vault-get-started/

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id')
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key')
vault_token=$(prop 'project' 'vault')

#set -x
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
vault -h

export VAULT_ADDR=http://vault.default.${eks_project}.${eks_domain}
vault login ${vault_token}

# aws key
vault secrets enable aws
vault write aws/config/root \
  access_key=${aws_access_key_id} \
  secret_key=${aws_secret_access_key} \
  region=us-west-1

exit 0

1. vault_service_policy

aws_account_id=$(aws sts get-caller-identity --query Account --output text)

echo '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Action": [ "iam:DeleteAccessKey", "iam:AttachUserPolicy", "iam:DeleteUserPolicy", "iam:DeleteUser", "iam:ListUserPolicies", "iam:CreateUser", "iam:CreateAccessKey", "iam:RemoveUserFromGroup", "iam:ListGroupsForUser", "iam:PutUserPolicy", "iam:ListAttachedUserPolicies", "iam:DetachUserPolicy", "iam:ListAccessKeys" ], "Resource": "*" } ] } ' > vault_policy
aws iam create-policy --policy-name vault_policy --policy-document file://vault_policy
aws iam create-user --user-name vault_service_policy
aws iam attach-user-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/vault_policy --user-name vault_service_policy

add vault_dev_user
Credential type: IAM User
with Policy document
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringEqulas": {
          "ec2:ResourceTag/Environment": "dev"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}

=> Generate AWS Credentials

2. secrets / aws_assume_role

# 2.1 create-role
aws iam delete-role --role-name assume_role_trust
echo '{ "Version": "2012-10-17", "Statement": { "Effect": "Allow", "Principal": { "AWS": "*" }, "Action": "sts:AssumeRole" } }' > assume_role_trust
aws iam create-role --role-name assume_role_trust --assume-role-policy-document file://assume_role_trust
assume_role_arn=$(aws iam get-role --role-name assume_role_trust | grep Arn | awk '{print $2}' | sed "s/\"//g;s/,//g")

# 2.2 create-policy
echo '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Action": "sts:AssumeRole", "Resource": "arn:aws:iam::aws_account_id:role/vault_readonly_role" } ] }' > vault_assume_role_policy
sed -i "s/aws_account_id/${aws_account_id}/g" vault_assume_role_policy

assume_role_policy_arn=$(aws iam list-policies | grep vault_assume_role_policy | grep Arn | awk '{print $2}' | sed "s/\"//g;s/,//g")
aws iam delete-policy --policy-arn ${assume_role_policy_arn}
aws iam create-policy --policy-name vault_assume_role_policy --policy-document file://vault_assume_role_policy

# 2.3 attach-role-policy
aws iam attach-role-policy --role-name assume_role_trust --policy-arn arn:aws:iam::${aws_account_id}:policy/vault_assume_role_policy

# 2.4 create user
aws iam create-user --user-name vault_assume_user
aws iam attach-user-policy --policy-arn arn:aws:iam::${aws_account_id}:policy/vault_assume_role_policy --user-name vault_assume_user
aws iam list-attached-user-policies --user-name vault_assume_user


add vault_readonly
Credential type: Assumed Role
Role ARNs: ${assume_role_arn}

Generate AWS Credentials =>
Credential type: Assumed Role

# create-policy
aws iam attach-role-policy --role-name example-role --policy-arn "arn:aws:iam::${aws_account_id}:role/assume_role_trust"
aws iam list-attached-role-policies --role-name example-role


