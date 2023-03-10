#!/bin/bash

DATA_DIR=/opt/bastion
OWNER=ubuntu

sudo mv ${DATA_DIR} "${DATA_DIR}_bak"

DEVICE='/dev/nvme1n1'
DEVICE_FS=`blkid -o value -s TYPE ${DEVICE}`
if [ "`echo -n $DEVICE_FS`" == "" ] ; then
  # wait for the device to be attached
  DEVICENAME=`echo "${DEVICE}" | awk -F '/' '{print $3}'`
  DEVICEEXISTS=''
  while [[ -z $DEVICEEXISTS ]]; do
    echo "checking $DEVICENAME"
    DEVICEEXISTS=`lsblk |grep "$DEVICENAME" |wc -l`
    if [[ $DEVICEEXISTS != "1" ]]; then
      sleep 15
    fi
  done
  sudo pvcreate ${DEVICE}
  sudo vgcreate data ${DEVICE}
  sudo lvcreate --name volume1 -l 100%FREE data
  sudo mkfs.ext4 /dev/data/volume1
fi
sudo mkdir -p ${DATA_DIR}
echo "/dev/data/volume1 ${DATA_DIR} ext4 defaults 0 0" >> /etc/fstab
sudo mount ${DATA_DIR}

sudo mv ${DATA_DIR}_bak/* ${DATA_DIR}_bak/.* ${DATA_DIR}/
sudo chown -Rf ${OWNER}:${OWNER} ${DATA_DIR}
sudo rm -Rf ${DATA_DIR}_bak

exit 0

tar cvfz /vagrant/terraform-aws-eks/resource/a.zip /vagrant/*.csv
scp -i ~/.ssh/eks-main /vagrant/terraform-aws-eks/resource/a.zip ubuntu@3.38.108.153:/home/ubuntu/resources
scp -i ~/.ssh/eks-main -r /home/vagrant/.aws ubuntu@3.38.108.153:/home/ubuntu/.aws
scp -i ~/.ssh/eks-main -r /home/vagrant/.kube ubuntu@3.38.108.153:/home/ubuntu/.kube
scp -i ~/.ssh/eks-main -r /home/vagrant/.ssh ubuntu@3.38.108.153:/home/ubuntu/.ssh

#mv /home/ubuntu/resources/a.zip /opt/bastion/a.zip

sudo chown -Rf ubuntu:ubuntu /opt/bastion
sudo mv /opt/bastion/746446553436-2021-07-AWS-Detail.csv /opt/bastion/aws_cost.csv
sudo apt-get update && sudo apt-get install mysql-client -y



NS=devops-dev
MYSQL_HOST=$(kubectl get svc mysql -n ${NS} | tail -n 1 | awk '{print $4}')
echo ${MYSQL_HOST}
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=$(kubectl get secret -n ${NS} mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)
echo $MYSQL_ROOT_PASSWORD

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} -e "CREATE database aws_usage;"
echo mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} -e "SHOW databases;"
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} -e "SHOW databases;"

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} aws_usage < ddl.sql

#mysqlimport --ignore-lines=1 --lines-terminated-by='\n' --fields-terminated-by=',' --fields-enclosed-by='"' \
#  --verbose -h ${MYSQL_HOST} --user=root -p${MYSQL_ROOT_PASSWORD} aws_usage /opt/bastion/aws_cost.csv

#kubectl -n ${NS} exec -i mysql-6f5f956f5b-vw6hn -- mysql -u root -p${MYSQL_ROOT_PASSWORD} < my_local_dump.sql

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD}

LOAD DATA LOCAL INFILE '/opt/bastion/aws_cost.csv'
INTO TABLE aws_usage.aws_cost
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


