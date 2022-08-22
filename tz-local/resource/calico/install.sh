#!/usr/bin/env bash

#https://docs.aws.amazon.com/eks/latest/userguide/calico.html

cd /vagrant/tz-local/resource/calico

#set -x
shopt -s expand_aliases
alias k='kubectl'

function prop {
	grep "${2}" "/home/vagrant/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')

kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/calico-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/calico-crs.yaml

kubectl get daemonset calico-node --namespace calico-system

#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/00-namespace.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/01-management-ui.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/02-backend.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/03-frontend.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/04-client.yaml

#kubectl get pods --all-namespaces --watch

#kubectl port-forward service/management-ui -n management-ui 8080:9001
#
#kubectl apply -n stars -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/policies/default-deny.yaml
#kubectl apply -n client -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/policies/default-deny.yaml
#
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/policies/allow-ui.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/policies/allow-ui-client.yaml
#
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/policies/backend-policy.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/policies/frontend-policy.yaml
#
#kubectl delete -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/04-client.yaml
#kubectl delete -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/03-frontend.yaml
#kubectl delete -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/02-backend.yaml
#kubectl delete -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/01-management-ui.yaml
#kubectl delete -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/tutorials/stars-policy/manifests/00-namespace.yaml



