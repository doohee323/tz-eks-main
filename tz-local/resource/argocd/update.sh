#!/usr/bin/env bash

source /root/.bashrc
cd /vagrant/tz-local/resource/argocd

#set -x
shopt -s expand_aliases

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
argocd_google_client_id=$(prop 'project' 'argocd_google_client_id')
argocd_google_client_secret=$(prop 'project' 'argocd_google_client_secret')

alias k='kubectl --kubeconfig ~/.kube/config'
argocd login `k get service -n argocd | grep argocd-server | awk '{print $4}' | head -n 1`:443 --username admin --password ${admin_password} --insecure

cp argocd-cm.yaml argocd-cm.yaml_bak
cp argocd-rbac-cm.yaml argocd-rbac-cm.yaml_bak

sed -i "s/eks_project/${eks_project}/g" argocd-cm.yaml_bak
sed -i "s/eks_domain/${eks_domain}/g" argocd-cm.yaml_bak
# OpenID Connect (google oauth2)
# https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/google/
sed -i "s/argocd_google_client_id/${argocd_google_client_id}/g" argocd-cm.yaml_bak
sed -i "s/argocd_google_client_secret/${argocd_google_client_secret}/g" argocd-cm.yaml_bak

PROJECTS=(default devops devops-dev)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    echo "====================="
    echo ${item}
    if [[ "${item/*-dev/}" == "" ]]; then
      project=${item/-prod/}
      echo "=====================dev"
    else
      project=${item/-dev/}
      echo "=====================prod"
    fi
#    argocd proj delete ${project}

    if [[ "${item/*-dev/}" == "" ]]; then
      argocd proj create ${project} \
        -d https://kubernetes.default.svc,${project} \
        -s https://github.com/doohee323/tz-argocd-repo.git \
        -s https://doohee323.github.io/tz-argocd-repo/ \
        --source-namespaces ${project}
      echo "  accounts.${project}: apiKey, login" >> argocd-cm.yaml_bak
      echo "    p, role:${project}, applications, sync, ${project}/*, allow" >> argocd-rbac-cm.yaml_bak
      echo "    g, ${project}, role:${project}" >> argocd-rbac-cm.yaml_bak
      argocd account update-password --account ${project} --current-password ${admin_password} --new-password 'imsi!323'
    else
      argocd proj create ${project} \
        -d https://kubernetes.default.svc,${project} \
        -d https://kubernetes.default.svc,${item}-dev \
        -s https://github.com/doohee323/tz-argocd-repo.git \
        -s https://doohee323.github.io/tz-argocd-repo/ \
        --source-namespaces ${project}
      echo "  accounts.${project}-admin: apiKey, login" >> argocd-cm.yaml_bak
      echo "    p, role:${project}-admin, *, *, ${project}/*, allow" >> argocd-rbac-cm.yaml_bak
      echo "    g, ${project}-admin, role:${project}-admin" >> argocd-rbac-cm.yaml_bak
      argocd account update-password --account ${project}-admin --current-password ${admin_password} --new-password 'imsi!323'
    fi
  fi
done
k apply -f argocd-cm.yaml_bak -n argocd
k apply -f argocd-rbac-cm.yaml_bak -n argocd
k apply -f argocd-cmd-params-cm.yaml -n argocd

exit 0
