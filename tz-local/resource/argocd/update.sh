#!/usr/bin/env bash

#https://faun.pub/create-argo-cd-local-users-9e830db3763f
#https://medium.com/finda-tech/eks-cluster%EC%97%90-argo-cd-%EB%B0%B0%ED%8F%AC-%EB%B0%8F-%EC%84%B8%ED%8C%85%ED%95%98%EB%8A%94-%EB%B2%95-eec3bef7b69b

source /root/.bashrc
#bash /vagrant/tz-local/resource/argocd/update.sh
cd /vagrant/tz-local/resource/argocd

#set -x
shopt -s expand_aliases

eks_project=$(prop 'project' 'project')
eks_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
argocd_google_client_id=$(prop 'project' 'argocd_google_client_id')
argocd_google_client_secret=$(prop 'project' 'argocd_google_client_secret')

alias k='kubectl --kubeconfig ~/.kube/config'
#alias k="kubectl --kubeconfig ~/.kube/kubeconfig_${eks_project}"

#argocd login localhost:8080
#argocd login argocd.${eks_domain}:443 --username admin --password ${admin_password} --insecure
#argocd login argocd.default.${eks_project}.${eks_domain}:443 --username admin --password ${admin_password} --insecure
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
        -s https://github.com/tzkr/tz-argocd-repo.git \
        -s https://tzkr.github.io/tz-argocd-repo/ \
        --source-namespaces ${project}
      echo "  accounts.${project}: apiKey, login" >> argocd-cm.yaml_bak
      echo "    p, role:${project}, applications, sync, ${project}/*, allow" >> argocd-rbac-cm.yaml_bak
      echo "    g, ${project}, role:${project}" >> argocd-rbac-cm.yaml_bak
      argocd account update-password --account ${project} --current-password ${admin_password} --new-password 'imsi!323'
    else
      argocd proj create ${project} \
        -d https://kubernetes.default.svc,${project} \
        -d https://kubernetes.default.svc,${item}-dev \
        -s https://github.com/tzkr/tz-argocd-repo.git \
        -s https://tzkr.github.io/tz-argocd-repo/ \
        --source-namespaces ${project}
      if [[ "${project}" == "datateam" ]]; then
        echo "  accounts.${project}-admin: apiKey, login" >> argocd-cm.yaml_bak
        echo "    p, role:${project}-admin, *, *, *, allow" >> argocd-rbac-cm.yaml_bak
        echo "    g, ${project}-admin, role:${project}-admin" >> argocd-rbac-cm.yaml_bak
        argocd account update-password --account ${project}-admin --current-password ${admin_password} --new-password 'imsi!323'
      else
        echo "  accounts.${project}-admin: apiKey, login" >> argocd-cm.yaml_bak
        echo "    p, role:${project}-admin, *, *, ${project}/*, allow" >> argocd-rbac-cm.yaml_bak
        echo "    g, ${project}-admin, role:${project}-admin" >> argocd-rbac-cm.yaml_bak
        argocd account update-password --account ${project}-admin --current-password ${admin_password} --new-password 'imsi!323'
      fi
    fi
  fi
done
k apply -f argocd-cm.yaml_bak -n argocd
k apply -f argocd-rbac-cm.yaml_bak -n argocd
k apply -f argocd-cmd-params-cm.yaml -n argocd

exit 0
