#!/usr/bin/env bash

HOST_IP=$1
KEY=$2

if [[ "${HOST_IP}" == "" ]]; then
  echo "HOST_IP is empty!"
  exit 1
fi

if [[ "${KEY}" == "" ]]; then
  echo "KEY is empty!"
  exit 1
fi

echo "
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
ExecStart=/home/ubuntu/node_exporter/node_exporter

[Install]
WantedBy=multi-user.target
" > node-exporter.service

echo "
#!/usr/bin/env bash

wget https://github.com/prometheus/node_exporter/releases/download/v1.1.2/node_exporter-1.1.2.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
ln -s node_exporter-*.*-amd64 node_exporter
#cd node_exporter-*.*-amd64
#./node_exporter

sudo mv /home/ubuntu/node-exporter.service /etc/systemd/system/node-exporter.service
sudo systemctl daemon-reload
sudo systemctl enable node-exporter
sudo systemctl start node-exporter
#sudo systemctl status node-exporter

sleep 5
curl -v http://localhost:9100/metrics
" > run.sh

scp -q -i ${KEY} node-exporter.service ubuntu@${HOST_IP}:/home/ubuntu
scp -q -i ${KEY} run.sh ubuntu@${HOST_IP}:/home/ubuntu
ssh -i ${KEY} ubuntu@${HOST_IP} "sudo bash run.sh"

rm -Rf node-exporter.service
rm -Rf run.sh

curl -v http://${HOST_IP}:9100/metrics

#ssh -i devops ubuntu@10.0.2.167
# 10.0.1.4
# 10.0.2.52
