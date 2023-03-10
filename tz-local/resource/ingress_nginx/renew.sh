#!/usr/bin/env bash

#bash /vagrant/tz-local/resource/ingress_nginx/renew.sh

#PROJECTS=($(kubectl get namespaces | awk '{print $1}' | tr '\n' ' '))
#PROJECTS=(datateam-dev lens- datateam kube-)
PROJECTS=(argocd consul common common-dev datateam datateam-dev default devops devops-dev extension extension-dev monitoring tgd tgd-dev twip twip-dev vault)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" && "${item}" != cert-* && "${item}" != kube-* && "${item}" != lens-* ]]; then
    echo "=== ${item} =================="
    kubectl cert-manager renew --namespace=${item} --all
  fi
done

exit 0