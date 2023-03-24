#!/usr/bin/env bash

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

PROJECTS=(default argocd devops devops-dev)
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
        -d https://kubernetes.default.svc,argocd \
        -s https://github.com/doohee323/tz-argocd-repo.git \
        -s https://doohee323.github.io/tz-argocd-repo/
      echo "  accounts.${project}: apiKey, login" >> argocd-cm.yaml_bak
      echo "    p, role:${project}, applications, sync, ${project}/*, allow" >> argocd-rbac-cm.yaml_bak
      echo "    g, ${project}, role:${project}" >> argocd-rbac-cm.yaml_bak
      argocd account update-password --account ${project} --current-password ${admin_password} --new-password 'imsi!323'
    else
      argocd proj create ${project} \
        -d https://kubernetes.default.svc,${project} \
        -d https://kubernetes.default.svc,${item}-dev \
        -d https://kubernetes.default.svc,argocd \
        -s https://github.com/doohee323/tz-argocd-repo.git \
        -s https://doohee323.github.io/tz-argocd-repo/
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

argocd login argocd.${eks_domain}:443 --username devops-dev --password imsi\!323 --insecure
argocd account can-i create projects '*'
argocd account can-i get projects '*'

argocd account list
argocd account get --account tz-admin
argocd account update-password --account tz-admin --current-password ${admin_password} --new-password ${admin_password}

argocd admin settings rbac can role:argocd-admin get applications --policy-file policy.csv

argocd proj list
PROJ=devops
ROLE=devops-admin
APP=devops-tz-demo-app

argocd proj delete $PROJ

argocd proj create $PROJ \
        -d https://kubernetes.default.svc,$PROJ \
        -d https://kubernetes.default.svc,$PROJ-dev \
        -d https://kubernetes.default.svc,argocd \
        -s https://github.com/doohee323/tz-argocd-repo.git \
        -s https://doohee323.github.io/tz-argocd-repo/

argocd proj role create $PROJ $ROLE
argocd proj role create $PROJ argocd-admin
argocd proj role list $PROJ
argocd proj role get $PROJ $ROLE

argocd proj role add-policy $PROJ $ROLE --action get --permission allow --object $APP

argocd app list
argocd app delete devops-tz-demo-app
argocd app create devops-tz-demo-app \
  --project devops \
  --repo https://github.com/doohee323/tz-argocd-repo.git \
  --path devops-tz-demo-app/prod \
  --dest-namespace devops \
  --dest-server https://kubernetes.default.svc --directory-recurse --upsert --grpc-web \
  --sync-policy automated \
  --sync-retry-limit 3 \
  --revision main