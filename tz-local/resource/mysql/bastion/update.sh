#!/usr/bin/env bash

#bash /vagrant/tz-local/resource/mysql/install.sh
cd /vagrant/tz-local/resource/mysql/bastion

kubectl cp devops-dev/mysql-5d94bc4676-22xp9:tmp/myoutput1.txt /vagrant/tz-local/resource/mysql/bastion/myoutput.txt

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
NS=devops-dev

# 1. make ubuntu pod as bastion
kubectl -n devops-dev apply -f ubuntu.yaml

# 2. upload aws, k8s credentials
kubectl -n devops-dev cp /home/vagrant/.aws devops-dev/bastion:/root/.aws
kubectl -n devops-dev cp /home/vagrant/.kube devops-dev/bastion:/root/.kube
kubectl -n devops-dev cp /home/vagrant/.ssh devops-dev/bastion:/root/.ssh
#kubectl -n devops-dev cp /vagrant/terraform-aws-eks/resource/5.zip devops-dev/bastion:/data
#kubectl -n devops-dev cp /vagrant/terraform-aws-eks/resource/7.zip devops-dev/bastion:/data
#kubectl -n devops-dev cp /vagrant/terraform-aws-eks/resource/8.zip devops-dev/bastion:/data
kubectl -n devops-dev cp /vagrant/tz-local/resource/mysql/bastion/ddl.sql devops-dev/bastion:/root

# 3. run ddl from bastion
MYSQL_HOST=$(kubectl -n devops-dev get svc mysql | tail -n 1 | awk '{print $4}')
echo ${MYSQL_HOST}
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=$(kubectl -n devops-dev get secret mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)
echo $MYSQL_ROOT_PASSWORD

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} -e "CREATE database aws_usage;"
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} -e "SHOW databases;"
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} aws_usage < ddl.sql

# 4. install utils in bastion
kubectl -n devops-dev exec -it bastion -- sh

cat 8.csv | grep 'AmazonRDS' | wc -l

apt-get update -y
apt-get install -y curl wget awscli jq unzip netcat apt-transport-https gnupg2

curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/aws-iam-authenticator
#curl -o aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
chmod +x aws-iam-authenticator
mv aws-iam-authenticator /usr/local/bin

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl

apt-get install mysql-client -y

#tar xvfz /data/7.zip
#mv /data/*.csv /data/aws_cost.csv

nc -zv mysql.devops-dev.svc.cluster.local 3306
MYSQL_HOST=mysql.devops-dev.svc.cluster.local
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=$(kubectl -n devops-dev get secret mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)
echo "MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}"
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --protocol tcp --user=root -p${MYSQL_ROOT_PASSWORD}

# import data
SET autocommit=0;
SET unique_checks=0;
SET foreign_key_checks=0;
COMMIT;

LOAD DATA LOCAL INFILE '/data/5.csv'
INTO TABLE aws_usage.aws_cost
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/data/6.csv'
INTO TABLE aws_usage.aws_cost
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/data/7.csv'
INTO TABLE aws_usage.aws_cost
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/data/8.csv'
INTO TABLE aws_usage.aws_cost
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


SET autocommit=1;
SET unique_checks=1;
SET foreign_key_checks=1;
COMMIT;

CREATE INDEX resourceid_idx ON aws_usage.aws_cost (resourceid);
CREATE INDEX resourceid_productcategory_idx ON aws_usage.aws_cost (resourceid, productcategory);
CREATE INDEX productcategory_idx ON aws_usage.aws_cost (productcategory);
SET sql_safe_updates=1, sql_select_limit=100000, max_join_size=3000000;

#aws describe-resource --resource-arn 'arn:aws:rds:ap-northeast-1:xxxxxxxxxxxxx:cluster:cluster-tdifecdq2vrhgrhvqob27zxn7q'
#aws rds describe-db-instances --filters Name=db-cluster-id,Values=arn:aws:rds:ap-northeast-1:xxxxxxxxxxxxx:cluster:cluster-tdifecdq2vrhgrhvqob27zxn7q

exit 0

NS=devops-dev
kubectl --kubeconfig ~/.kube/kubeconfig_eks-main -n ${NS} port-forward svc/mysql 3306

pushd `pwd`
cd /vagrant/terraform-aws-eks/workspace/base
bastion_ip=$(terraform output | grep eks-main-bastion | awk '{print $3}' | tr "/" "\n" | tail -n 1)
popd
echo bastion_ip: ${bastion_ip}

#KEY_FILE='/Volumes/workspace/tz/tz-eks-main/terraform-aws-eks/workspace/base/eks-main'
KEY_FILE='/vagrant/terraform-aws-eks/workspace/base/eks-main'
echo ssh -i ${KEY_FILE} ubuntu@${bastion_ip}

ssh -i ${KEY_FILE} \
-NL 22:topzone2-prod.cluster-c01spz81v11d.ap-northeast-2.rds.amazonaws.com:3306 \
ubuntu@52.79.56.74

redis-cli -h clustercfg.topzone-prod.etokrl.apn2.cache.amazonaws.com -p 6379
clustercfg.topzone-prod.etokrl.apn2.cache.amazonaws.com