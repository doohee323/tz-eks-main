#!/usr/bin/env bash

#set -x
shopt -s expand_aliases
alias k='kubectl'

export VER="1.8.4"
wget https://releases.hashicorp.com/consul/${VER}/consul_${VER}_linux_amd64.zip

sudo apt update
sudo apt install unzip -y
unzip consul_${VER}_linux_amd64.zip
rm -Rf ${VER}/consul_${VER}_linux_amd64.zip

chmod +x consul
sudo mv consul /usr/local/bin/

consul version

sudo groupadd --system consul
sudo useradd -s /sbin/nologin --system -g consul consul

/bin/mkdir -p /var/run/consul
/bin/chown -R consul:consul /var/run/consul

# 192.168.1.10: server1.dc1.consul's ip
# 172.16.247.7: consul-server-0
# 172.16.84.173: consul-server-1
# 172.16.235.236: consul-server-2

echo '
{
  "server": false,
  "datacenter": "tz-dc",
  "node_name": "server1.dc1.consul2",
  "data_dir": "/var/consul/data",
  "bind_addr": "192.168.1.10",
  "client_addr": "127.0.0.1",
  "retry_join": ["172.16.247.7", "172.16.84.173", "172.16.235.236"],
  "log_level": "DEBUG",
  "enable_syslog": true,
  "acl_enforce_version_8": false
}
' >> /usr/local/etc/consul/consul_c1.json
cat /usr/local/etc/consul/consul_c1.json

# /usr/local/bin/consul agent -config-file=/usr/local/etc/consul/consul_c1.json

echo '
### BEGIN INIT INFO
# Provides:          consul
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Consul agent
# Description:       Consul service discovery framework
### END INIT INFO

[Unit]
Description=Consul client agent
Requires=network-online.target
After=network-online.target

[Service]
#User=consul
#Group=consul
PIDFile=/var/run/consul/consul.pid
PermissionsStartOnly=true
ExecStartPre=-/bin/mkdir -p /var/run/consul
ExecStartPre=/bin/chown -R consul:consul /var/run/consul
ExecStart=/usr/local/bin/consul agent \
    -config-file=/usr/local/etc/consul/consul_c1.json \
    -pid-file=/var/run/consul/consul.pid
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/consul.service

sudo systemctl enable consul
sudo systemctl start consul
