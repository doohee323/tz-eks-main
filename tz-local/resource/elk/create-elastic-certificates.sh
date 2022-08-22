#!/bin/bash
# Usage: STACK_VERSION=7.5.2 DNS_NAME=elasticsearch NAMESPACE=default ./create-elastic-certificates.sh

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
ELASTIC_PASSWORD=$(prop 'project' 'admin_password')
echo "ELASTIC_ADMIN: elastic"
echo "ELASTIC_PASSWORD: ${ELASTIC_PASSWORD}"
export STACK_VERSION=7.13.2
NS=elk
DNS_NAME=$1
if [[ "${DNS_NAME}" == "" ]]; then
  DNS_NAME=elasticsearch-master
fi
DNS_NAME2=${DNS_NAME}.elk.svc.cluster.local
echo "DNS_NAME: ${DNS_NAME}"
echo "DNS_NAME2: ${DNS_NAME2}"

ELASTICSEARCH_IMAGE=docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}

kubectl -n ${NS} delete secrets elastic-credentials elastic-certificates elastic-certificate-pem elastic-certificate-crt

docker rm -f elastic-helm-charts-certs || true
	rm -f elastic-certificates.p12 elastic-certificate.pem elastic-certificate.crt elastic-stack-ca.p12 || true
	password=$([ ! -z "$ELASTIC_PASSWORD" ] && echo $ELASTIC_PASSWORD || echo $(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -cd '[:alnum:]' | head -c20")) && \
	docker run --name elastic-helm-charts-certs -i -w /tmp \
		${ELASTICSEARCH_IMAGE} \
		/bin/sh -c " \
			elasticsearch-certutil ca --out /tmp/elastic-stack-ca.p12 --pass '' && \
			elasticsearch-certutil cert --name $DNS_NAME --dns $DNS_NAM2 --ca /tmp/elastic-stack-ca.p12 --pass '' --ca-pass '' --out /tmp/elastic-certificates.p12" && \
	docker cp elastic-helm-charts-certs:/tmp/elastic-certificates.p12 ./ && \
	docker rm -f elastic-helm-charts-certs && \
	openssl pkcs12 -nodes -passin pass:'' -in elastic-certificates.p12 -out elastic-certificate.pem && \
	openssl x509 -outform der -in elastic-certificate.pem -out elastic-certificate.crt && \
	kubectl -n ${NS} create secret generic elastic-certificates --from-file=elastic-certificates.p12 && \
	kubectl -n ${NS} create secret generic elastic-certificate-pem --from-file=elastic-certificate.pem && \
	kubectl -n ${NS} create secret generic elastic-certificate-crt --from-file=elastic-certificate.crt && \
	kubectl -n ${NS} create secret generic elastic-credentials --from-literal=password=${password} --from-literal=username=elastic && \
	rm -f elastic-certificates.p12 elastic-certificate.pem elastic-certificate.crt elastic-stack-ca.p12

exit 0

./bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12 --ip 10.0.0.5,10.0.0.6,10.0.0.7 --dns node1.elk.com,node2.elk.com,logstash.elk.com



