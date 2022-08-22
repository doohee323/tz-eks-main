#!/usr/bin/env bash

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
admin_password=$(prop 'project' 'admin_password')

curl -XDELETE -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/role/logstash_writer'
curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/role/logstash_writer' -d '
{
  "cluster": ["manage_index_templates", "monitor", "all"],
  "indices": [
    {
      "names": [ "nginx*" ], 
      "privileges": ["read","write","delete","create_index"]
    },
    {
      "names": [ "stats*" ], 
      "privileges": ["read","write","delete","create_index"]
    },
    {
      "names": [ "my_index*" ],
      "privileges": ["read","write","delete","create_index"]
    }
  ]
}'


curl -XGET -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/role/logstash_writer'

curl -XDELETE -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/logstash_internal'
curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/logstash_internal' -d '
{
  "password" : "tzcorp!323",
  "roles" : [ "logstash_writer", "logstash_system" ],
  "full_name" : "Internal Logstash User"
}'

#PUT _xpack/security/user/logstash_system/_enable
curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/logstash_system/_enable'

curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/logstash_internal/_enable'

curl -XGET -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/role/logstash_writer?pretty'
curl -XGET -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/logstash_internal?pretty'

# get user info
curl -XGET -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user?pretty'
curl -XGET -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/role?pretty'

exit 0

curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/elastic/_password' -d '{
  "password" : "tzcorp!323"
}'

curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/kibana/_password' -d '{
  "password" : "tzcorp!323"
}'

curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/logstash_system/_password' -d '{
  "password" : "xxxx!323"
}'

curl -XPUT -H "Content-Type: application/json" -u "elastic:${admin_password}" 'https://es.tzcorp.com/_xpack/security/user/logstash_internal/_password' -d '{
  "password" : "tzcorp!323"
}'


cd /usr/share/es1/bin/x-pack

bin/x-pack/users list
#bin/x-pack/users useradd doohee -r superuser

./users passwd elastic -p "tzcorp!323"
./users passwd kibana -p "tzcorp!323"
./users passwd logstash_system -p "tzcorp!323"
./users passwd logstash_internal -p "tzcorp!323"
./users useradd <username> -p <password>
./users useradd <username> -r <comma-separated list of role names>





