#!/usr/bin/env bash

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

cd /vagrant/tz-local/resource/postgresql

NS=devops

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm uninstall postgresql-cluster -n ${NS}

#DB_DATABASE_DEVELOPMENT=flanet
#READ_DB_USER_DEVELOPMENT=chharam_dev

helm uninstall postgresql-cluster -n ${NS}
helm upgrade --install postgresql-cluster -f values.yaml bitnami/postgresql -n ${NS}

sleep 30

export PSQL_PASSWORD=$(kubectl get secret -n ${NS} postgresql-cluster -o jsonpath="{.data.postgresql-password}" | base64 --decode)
echo "PSQL_PASSWORD: $PSQL_PASSWORD"
kubectl run postgresql-cluster-client --rm --tty -i --restart='Never' -n ${NS} \
  --image docker.io/bitnami/postgresql:11.12.0-debian-10-r70 \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql --host postgresql-cluster -U postgres -d postgres -p 5432

#k patch StatefulSet/postgresql-cluster-postgresql -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n ${NS}

sleep 200

#kubectl run -it busybox --image=alpine:3.6 -n devops --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "prod" } } }' -- sh
#nc -zv postgresql-cluster.devops.svc.cluster.local 5432

exit 0

PSQL_HOST=$(kubectl get svc postgresql-cluster -n ${NS} | tail -n 1 | awk '{print $4}')
echo "PSQL_HOST: ${PSQL_HOST}"
PSQL_PORT=5432

#sudo apt-get install postgresql -y
psql -h ${PSQL_HOST} -p ${PSQL_PORT} -d postgres -U postgres --password
#telnet ${PSQL_HOST} ${PSQL_PORT}


CREATE DATABASE flanet;
CREATE USER chharam_dev WITH PASSWORD '1234qwer';
GRANT ALL PRIVILEGES ON DATABASE flanet TO chharam_dev;
SELECT usename,valuntil FROM pg_user;
ALTER USER chharam_dev VALID UNTIL 'infinity';
ALTER USER chharam_dev WITH PASSWORD '1234qwer';

SELECT usename AS role_name,
  CASE
     WHEN usesuper AND usecreatedb THEN
	   CAST('superuser, create database' AS pg_catalog.text)
     WHEN usesuper THEN
	    CAST('superuser' AS pg_catalog.text)
     WHEN usecreatedb THEN
	    CAST('create database' AS pg_catalog.text)
     ELSE
	    CAST('' AS pg_catalog.text)
  END role_attributes
FROM pg_catalog.pg_user
ORDER BY role_name desc;





