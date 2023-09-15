#!/usr/bin/env bash
#set -x

# It should be in /var/lib/jenkins/k8s.sh
shopt -s expand_aliases
alias trace_on='set -x'
alias trace_off='{ set +x; } 2>/dev/null'

echo "~~~~~~~~~~~~~ 1"
env
echo "~~~~~~~~~~~~~ 2"

#WORKING_HOME=/var/lib/jenkins
WORKING_HOME=/root

function prop {
  if [[ "${3}" == "" ]]; then
    grep "${2}" "${WORKING_HOME}/.aws/${1}" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
  else
    grep "${3}" "${WORKING_HOME}/.aws/${1}" -A 10 | grep "${2}" | head -n 1 | tail -n 1 | cut -d '=' -f2 | sed 's/ //g'
  fi
}

if [[ "${CLUSTER_NAME}" == "" ]]; then
    CLUSTER_NAME="eks-main-t"
fi

CONFIG_FILE=$(echo ${CLUSTER_NAME} | sed 's/eks-main/project/')
#echo "CLUSTER_NAME: ${CLUSTER_NAME}"
#echo "CONFIG_FILE: ${CONFIG_FILE}"

git_id=$(prop ${CONFIG_FILE} 'git_id')
git_token=$(prop ${CONFIG_FILE} 'git_token')
eks_domain=$(prop ${CONFIG_FILE} 'domain')
vault_token=$(prop ${CONFIG_FILE} 'vault')
argocd_id=$(prop ${CONFIG_FILE} 'argocd_id')
admin_password=$(prop ${CONFIG_FILE} 'admin_password')
aws_access_key_id=$(prop 'credentials' 'aws_access_key_id' ${CLUSTER_NAME})
aws_secret_access_key=$(prop 'credentials' 'aws_secret_access_key' ${CLUSTER_NAME})
aws_default_region=$(prop 'config' 'region' ${CLUSTER_NAME})

AWS_ACCESS_KEY_ID=${aws_access_key_id}
AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
AWS_DEFAULT_REGION=${aws_default_region}
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}" >> log
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}" >> log
echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}" >> log

ACTION=${1}

if [[ "${ACTION}" == "" ]]; then
  echo "ACTION is none!"
  exit 1
fi

if [[ "${ACTION}" == "prop" ]]; then
  config_key=$2
  eval echo "${!config_key}"
  exit 1
fi

if [[ "${ACTION}" == "vault" ]]; then
  export VAULT_ADDR=https://vault.default.eks-main-t.shoptoolstest.co.kr
  login_out=$(vault login ${vault_token})
  vault_secret_key=$2
  fields=($(echo "$3" | tr ',' '\n'))
  for item in "${fields[@]}"; do
    rslt=$(vault kv get -field=${item} ${vault_secret_key})
    echo ${rslt}
  done
  exit 0
fi

if [[ "${ACTION}" == "vault_config" ]]; then
  export VAULT_ADDR=https://vault.default.eks-main-t.shoptoolstest.co.kr
  login_out=$(vault login ${vault_token})
  vault_secret_key=$2
  vault_secret_key2=$3
  tmp=tmp_$(shuf -i 0-1000 -n 1)
  echo "" > .env
  echo "" > ${tmp}
  if [[ "${vault_secret_key2}" != "" ]]; then
#    echo "====================${vault_secret_key2}====================" >> ${tmp}
    vault kv get -mount=secret -format=json ${vault_secret_key}/${vault_secret_key2} | jq -r .data.data >> ${tmp}
    echo "" >> ${tmp}
  else
    vault kv get -mount=secret -format=json ${vault_secret_key} | jq -r .data.data >> ${tmp}
  fi
  if [[ "${4}" == "-json" ]]; then
    cp -Rf ${tmp} .env
  else
    cat ${tmp} | jq -r 'keys_unsorted[] as $key|"\($key)=\(.[$key])"' >> .env
  fi
  cat .env && rm -Rf ${tmp}
  exit 0
fi

echo "================================================"
echo "aws sts get-caller-identity --profile ${CLUSTER_NAME}"
aws sts get-caller-identity --profile ${CLUSTER_NAME}
echo "================================================"
echo "****** ACTION: $1"
echo "================================================"

if [[ "${WORKSPACE}" == "" ]]; then
  echo "WORKSPACE is none!"
  exit 1
fi

if [[ "${APP_NAME}" == "" ]]; then
  echo "APP_NAME is none!"
  exit 1
fi

if [[ "${BUILD_NUMBER}" == "" ]]; then
  echo "BUILD_NUMBER is none!"
  exit 1
fi

echo "FORCED_PROD: ${FORCED_PROD}"
echo "FORCED_STAGING: ${FORCED_STAGING}"
echo "FORCED_QA: ${FORCED_QA}"

export ORI_GIT_BRANCH=${GIT_BRANCH}
export GIT_BRANCH=$(echo ${ORI_GIT_BRANCH} | sed 's/\//-/g')
GIT_BRANCH=$(echo ${GIT_BRANCH} | cut -b1-21 | tr '[:upper:]' '[:lower:]')
echo "GIT_BRANCH: ${GIT_BRANCH}"
if [[ "${FORCED_PROD}" == "true" ]]; then
  export STAGING=prod
else
  if [[ "${FORCED_STAGING}" == "true" ]]; then
    export STAGING=staging
  elif [[ "${FORCED_QA}" == "true" ]]; then
    export STAGING=qa
  else
    if [[ "${GIT_BRANCH}" == "master" || "${GIT_BRANCH}" == "main" ]]; then
      export STAGING=prod
    elif [[ "${STAGING}" == "" ]]; then
      export STAGING=dev
    fi
  fi
fi

if [[ "${TAG_ID}" != "latest" ]]; then
  TAG_ID=`echo ${GIT_BRANCH} | md5sum | cut -b1-5`-${TAG_ID}
fi
echo "TAG_ID: ${TAG_ID}"
if [[ "${IMAGE_TAG}" == "" ]]; then
  IMAGE_TAG="${DOCKER_NAME}:${TAG_ID}"
fi
echo "IMAGE_TAG: ${IMAGE_TAG}"
if [[ "${REPO_HOST}" == "" ]]; then
  REPO_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
fi
echo "REPO_HOST: ${REPO_HOST}"
if [[ "${REPOSITORY_TAG}" == "" ]]; then
  export REPOSITORY_TAG="${REPO_HOST}/${IMAGE_TAG}"
fi
echo "REPOSITORY_TAG: ${REPOSITORY_TAG}"
if [[ "${REPO_HOST_URL}" == "" ]]; then
  REPO_HOST_URL="https://${REPO_HOST}"
fi
echo "REPO_HOST_URL: ${REPO_HOST_URL}"
if [[ "${REGISTRY_CREDENTIAL}" == "" ]]; then
  REGISTRY_CREDENTIAL="jenkins-aws-secret"
fi
echo "REGISTRY_CREDENTIAL: ${REGISTRY_CREDENTIAL}"

SOURCE_K8S_FILE=${WORKSPACE}/k8s.yaml
SOURCE_DOCKER_FILE=${WORKSPACE}/Dockerfile
ORI_APP_NAME=${APP_NAME}
if [[ "${STAGING}" == "prod" ]]; then
  APP_NAME=${ORI_APP_NAME}
  K8S_FILE=${K8S_FILE/-dev/}
  if [[ "${K8S_DIR}" != "" ]]; then
    SOURCE_K8S_FILE=${WORKSPACE}/${K8S_DIR}/k8s.yaml
  fi
else
  if [[ "${BRANCH_ROLLOUT}" == "true" ]]; then
    if [[ "${K8S_DIR}" != "" ]]; then
      if [[ "${STAGING}" == "staging" ]]; then
        APP_NAME=${ORI_APP_NAME}-staging
        SOURCE_K8S_FILE=${WORKSPACE}/${K8S_DIR}/k8s-staging.yaml
      elif [[ "${STAGING}" == "qa" ]]; then
        APP_NAME=${ORI_APP_NAME}-qa
        SOURCE_K8S_FILE=${WORKSPACE}/${K8S_DIR}/k8s-qa.yaml
      else
        APP_NAME=${ORI_APP_NAME}-${GIT_BRANCH}
        SOURCE_K8S_FILE=${WORKSPACE}/${K8S_DIR}/k8s-dev.yaml
      fi
    fi
  elif [[ "${BRANCH_ROLLOUT}" == "false" ]]; then
    APP_NAME=${ORI_APP_NAME}
    if [[ "${K8S_DIR}" != "" ]]; then
      if [[ "${STAGING}" == "staging" ]]; then
        SOURCE_K8S_FILE=${WORKSPACE}/${K8S_DIR}/k8s-staging.yaml
      elif [[ "${STAGING}" == "qa" ]]; then
        SOURCE_K8S_FILE=${WORKSPACE}/${K8S_DIR}/k8s-qa.yaml
      else
        SOURCE_K8S_FILE=${WORKSPACE}/${K8S_DIR}/k8s.yaml
      fi
    fi
  fi
fi
echo "ORI_APP_NAME: ${ORI_APP_NAME}"
echo "APP_NAME: ${APP_NAME}"
if [[ "${STAGING}" == "prod" || "${STAGING}" == "staging" || "${STAGING}" == "qa" ]]; then
  NAMESPACE=${NAMESPACE/-dev/}
  NAMESPACE=${NAMESPACE/-prod/}
  PROJECT=${NAMESPACE}
else
  if [[ $NAMESPACE != *-dev ]]; then
    NAMESPACE=${NAMESPACE}"-dev"
  else
    NAMESPACE=${NAMESPACE}
  fi
  PROJECT=${NAMESPACE/-dev/}
fi
KUBECTL="kubectl -n ${NAMESPACE} --kubeconfig ${WORKING_HOME}/.kube/tz_${CLUSTER_NAME}"
echo "================================================"

function k8s_init {
  echo "#######################################"
  echo k8s init
  echo "#######################################"
  REPO_IMAGE=$(aws ecr list-images --repository-name ${DOCKER_NAME})
  if [[ $? != 0 ]]; then
    aws ecr create-repository \
        --repository-name ${DOCKER_NAME} \
        --image-tag-mutability IMMUTABLE
    sleep 3
  fi
}

function k8s_file {
  TARGET_K8S_FILE="${WORKSPACE}/k8s_file.yaml"
  echo "#######################################"
  echo "envsubst < ${SOURCE_K8S_FILE} > ${TARGET_K8S_FILE}"
  echo "#######################################"
  envsubst < "${SOURCE_K8S_FILE}" > "${TARGET_K8S_FILE}"
  echo "========================"
  cat ${TARGET_K8S_FILE}
  echo "========================"
}

function argocd_init {
  echo "#######################################"
  echo apply to argocd
  echo "#######################################"
  pwd
  echo argocd login argocd.default.${CLUSTER_NAME}.${eks_domain}:443
  argocd login argocd.default.${CLUSTER_NAME}.${eks_domain}:443 --username ${argocd_id} --password ${admin_password} --insecure
  trace_on
  argocd app create ${APP_NAME} \
    --project ${PROJECT} \
    --repo https://bitbucket.org/seerslab/tz-argocd-repo.git \
    --path ${APP_NAME} \
    --dest-namespace ${NAMESPACE} \
    --dest-server https://kubernetes.default.svc --directory-recurse --upsert --grpc-web
  if [[ $? != 0 ]]; then
    echo "Error occurred!"
    alert_slack
    exit 1
  fi
  argocd app sync ${APP_NAME}
  trace_off
}

function argocd_delete {
  echo "#######################################"
  echo apply to argocd
  echo "#######################################"
  pwd
  echo argocd login argocd.default.${CLUSTER_NAME}.${eks_domain}:443
  argocd login argocd.default.${CLUSTER_NAME}.${eks_domain}:443 --username ${argocd_id} --password ${admin_password} --insecure
  trace_on
  argocd app delete ${APP_NAME3} -y
  trace_off
}

#SLACK_DEVOPS=https://hooks.slack.com/services/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 # eks_alert
SLACK_DEVOPS=https://hooks.slack.com/services/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 # devop
function alert_slack {
  echo ""
#  curl -X POST -H 'Content-type: application/json' --data '{"text":"build error '${APP_NAME}' - '${BUILD_URL}'"}' ${SLACK_DEVOPS}
}

if [[ "${ACTION}" == "init" ]]; then
  k8s_init
elif [[ "${ACTION}" == "argocd_init" ]]; then
  argocd_init
elif [[ "${ACTION}" == "argocd_delete" ]]; then
  argocd_delete
elif [[ "${ACTION}" == "build" ]]; then
  echo "#######################################"
  echo "BUILD_CMD: ${BUILD_CMD}"
  echo "#######################################"

  echo "AWS_REGION: ${AWS_REGION}"
  echo "CLUSTER_NAME: ${CLUSTER_NAME}"
  echo "ACCOUNT_ID: ${ACCOUNT_ID}"
  aws ecr get-login-password --profile ${CLUSTER_NAME} --region ${AWS_REGION} \
      | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

  if [[ "${BUILD_CMD}" != "" ]]; then
    ${BUILD_CMD}
  fi
echo "~~~~~~~~~~~~~ 111"
  service docker start
echo "~~~~~~~~~~~~~ 12233"
  if [[ "${BUILD_CMD_ONLY}" != "yes" ]]; then
    trace_on
    pwd
    if [[ "${STAGING}" == "prod" && "${OUTPUT}" == "out" ]]; then
      rm -Rf out && mkdir out
#      export DOCKER_BUILDKIT=1
#      docker build -f Dockerfile -t ${REPOSITORY_TAG} . \
#        --build-arg NODE_ENV=${NODE_ENV} \
#        --build-arg STAGING_ENV=${STAGING_ENV} \
#        --output out
#      if [[ $? != 0 ]]; then
        echo /kaniko/executor --dockerfile=Dockerfile --context=${WORKSPACE} ${args} --destination=${REPOSITORY_TAG} --destination="${REPO_HOST}/${DOCKER_NAME}:latest" --use-new-run --snapshot-mode=redo
    sleep 200
        /kaniko/executor --dockerfile=Dockerfile --context=${WORKSPACE} ${args} --destination=${REPOSITORY_TAG} --destination="${REPO_HOST}/${DOCKER_NAME}:latest" --use-new-run --snapshot-mode=redo
#      fi
    fi
    # docker build --no-cache -f Dockerfile -t ${REPOSITORY_TAG} . --build-arg NODE_ENV=${NODE_ENV} --build-arg STAGING_ENV=${STAGING_ENV} --build-arg FONT_AWESOME_TOKEN=${FONT_AWESOME_TOKEN} --output out
#    docker build --no-cache -f Dockerfile -t ${REPOSITORY_TAG} . \
#      --build-arg NODE_ENV=${NODE_ENV} \
#      --build-arg STAGING_ENV=${STAGING_ENV} \
#      --build-arg FONT_AWESOME_TOKEN=${FONT_AWESOME_TOKEN}
#    if [[ $? != 0 ]]; then
      echo /kaniko/executor --dockerfile=Dockerfile --context=${WORKSPACE} ${args} --destination=${REPOSITORY_TAG} --use-new-run --snapshot-mode=redo
    sleep 200
      /kaniko/executor --dockerfile=Dockerfile --context=${WORKSPACE} ${args} --destination=${REPOSITORY_TAG} --use-new-run --snapshot-mode=redo
#    fi
    if [[ $? != 0 ]]; then
      echo "Error occurred!"
      alert_slack
      exit 1
    fi
    IMG_TAG=(${REPOSITORY_TAG//:/ })
    if [[ "${STAGING}" == "prod" ]]; then
      echo docker image tag ${REPOSITORY_TAG} ${IMG_TAG[0]}:latest
      docker image tag ${REPOSITORY_TAG} ${IMG_TAG[0]}:latest
    elif [[ "${STAGING}" == "staging" || "${STAGING}" == "qa" ]]; then
      echo docker image tag ${REPOSITORY_TAG} ${IMG_TAG[0]}:qa
      docker image tag ${REPOSITORY_TAG} ${IMG_TAG[0]}:qa
    fi
    trace_off
  fi
elif [[ "${ACTION}" == "push" ]]; then
  k8s_init
  echo "#######################################"
  echo Push image
  echo "#######################################"
  trace_on
  aws ecr get-login-password --profile ${CLUSTER_NAME} --region ${AWS_REGION} \
    | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
  docker push ${REPO_HOST}/${IMAGE_TAG}
  if [[ $? != 0 ]]; then
    echo "Error occurred!"
    alert_slack
    exit 1
  fi
  IMG_TAG=(${REPOSITORY_TAG//:/ })
  if [[ "${STAGING}" == "prod" ]]; then
    echo docker push ${IMG_TAG[0]}:latest
    docker push ${IMG_TAG[0]}:latest
  elif [[ "${STAGING}" == "staging" || "${STAGING}" == "qa" ]]; then
    echo docker push ${IMG_TAG[0]}:qa
    docker push ${IMG_TAG[0]}:qa
  fi
  trace_off
elif [[ "${ACTION}" == "apply" ]]; then
  echo "#################################"
  echo "APP_NAME: ${APP_NAME}"
  echo "STAGING: ${STAGING}"
  echo "BRANCH_ROLLOUT: ${BRANCH_ROLLOUT}"
  echo "SOURCE_K8S_FILE: ${SOURCE_K8S_FILE}"
  echo "NAMESPACE: ${NAMESPACE}"
  echo "PROJECT: ${PROJECT}"
  echo "KUBECTL: ${KUBECTL}"
  env
  echo "#################################"
  k8s_file

  echo "#######################################"
  echo apply to k8s
  echo "#######################################"
  trace_on
  ${KUBECTL} apply -f ${TARGET_K8S_FILE} --record=true
  trace_off

  echo "#######################################"
  echo commit and push the char to git repo
  echo "#######################################"
  pwd
  git clone "https://${git_id}:${git_token}@bitbucket.org/seerslab/tz-argocd-repo.git" tz-argocd-repo
  rm -Rf tz-argocd-repo/${APP_NAME}
  mkdir -p tz-argocd-repo/${APP_NAME}
  trace_on
  cp ${TARGET_K8S_FILE} tz-argocd-repo/${APP_NAME}
  trace_off

  pushd `pwd`
  cd tz-argocd-repo
  git add .
  git commit -m 'Update chart'
  git remote set-url origin "https://${git_id}:${git_token}@bitbucket.org/seerslab/tz-argocd-repo.git"
  git push origin main -f
  echo "#######################################"
  echo remove working dirs
  echo "#######################################"
  rm -Rf tz-argocd-repo

  if [[ "${STAGING}" == "prod" || "${STAGING}" == "staging" || "${STAGING}" == "qa" ]]; then
    argocd_init
  fi
  pushd
  if [[ "$(kubectl get csr -o name)" != "" ]]; then
    kubectl get csr -o name | xargs kubectl certificate approve
  fi

  if [[ "${BACKUP}" == "true" && "${BACKUP_LABEL}" != "" ]]; then
    echo "#######################################"
    echo velero backup create
    echo "#######################################"
    BACKUP_LABEL=(`echo ${BACKUP_LABEL} | tr ',' ' '`)
    selector=""
    for label in "${BACKUP_LABEL[@]}"; do
      selector="${selector} --selector ${label}"
    done
    cmd="velero backup create ${APP_NAME} ${selector} -n velero"
    echo ${cmd}
    export KUBECONFIG="${WORKING_HOME}/.kube/tz_${CLUSTER_NAME}"
    `${cmd}`
    velero schedule create ${APP_NAME} --schedule="@every 10m" \
      --include-namespaces ${APP_NAME} \
      --ttl 24h0m0s \
      -n velero
  fi

  if [[ "${STAGING}" != "prod" && "${STAGING}" != "staging" && "${STAGING}" != "qa" ]]; then
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo " Removed branch resources "
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    APP_NAME2="${ORI_APP_NAME}-"
    DEPLOYMENTS=$(${KUBECTL} get deployment | grep ${APP_NAME2} | awk '{print $1}' | tr '\n' ' ')
    echo "DEPLOYMENTS: ${DEPLOYMENTS}"
    DEPLOYMENTS=(${DEPLOYMENTS})
    BRANCHES=$(git branch -r | tr '\n' '|' | sed 's/\//-/g' | tr '[:upper:]' '[:lower:]')
    echo "BRANCHES: ${BRANCHES}"
    for branch in "${DEPLOYMENTS[@]}"; do
      branch="${branch//$APP_NAME2/}"
      GIT_BRANCH2=`echo ${GIT_BRANCH} | sed 's/\//-/g'`
      GIT_BRANCH2=`echo ${GIT_BRANCH2} | cut -b1-21 | tr '[:upper:]' '[:lower:]'`
      if [[ "${GIT_BRANCH2}" != "${branch}" ]]; then
        match=$(echo ${BRANCHES} | grep -o "origin-${branch}")
        if [[ "${match}" == "" ]]; then
          echo "#######################################"
          echo "# Removed branch: ${branch}"
          echo "#######################################"
          APP_NAME3=${APP_NAME2}${branch}
          ${KUBECTL} delete deployment ${APP_NAME3}
          ${KUBECTL} delete svc ${APP_NAME3}
          ${KUBECTL} delete ingress ${APP_NAME3}
          ${KUBECTL} delete serviceaccount ${APP_NAME3}-svcaccount
          argocd app delete ${APP_NAME3} -y
  #        argocd app list | grep Missing | awk '{print "argocd app delete " $1 " -y"}'
        fi
      fi
    done
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  fi

elif [[ "${ACTION}" == "delete" ]]; then
  echo "#######################################"
  echo delete in k8s
  echo "#######################################"
  k8s_file

  trace_on
  ${KUBECTL} delete -f ${TARGET_K8S_FILE}
  if [[ $? != 0 ]]; then
    echo "Error occurred!"
  fi
  trace_off

  #echo "#######################################"
  #echo delete in argocd
  #echo "#######################################"
  #argocd app delete ${APP_NAME}
elif [[ "${ACTION}" == "verify" ]]; then
  trace_on
  DEPLOYMENT=${APP_NAME}
  if [[ "$2" != "" ]]; then
    DEPLOYMENT=${2}
  fi
  ${KUBECTL} rollout status deployment/${DEPLOYMENT} --timeout=120s
  if [[ $? != 0 ]]; then
    echo "Failed to deploy in k8s!!!"
    alert_slack
    exit 1
  fi
  trace_off
elif [[ "${ACTION}" == "internal" ]]; then
  k8s_file
  echo "TARGET_K8S_FILE: ${TARGET_K8S_FILE}"
  if [[ "`grep "\"nginx-internal\"" ${TARGET_K8S_FILE}`" != "" ]]; then
    trace_on
    INGRESS_NAME=`grep "\"nginx-internal\"" ${TARGET_K8S_FILE} -B 10 | grep "name:" | awk '{print $2}'`
    echo "INGRESS_NAME: ${INGRESS_NAME}"
    ELB_NM=`${KUBECTL} get ingress ${INGRESS_NAME} | awk '{print $3}' | tail -n 1`
    ELB=$(echo ${ELB_NM} | cut -d "-" -f 1)
    echo "ELB: ${ELB}"
    SQG=$(aws elb describe-load-balancers --query 'LoadBalancerDescriptions[*].[LoadBalancerName,SecurityGroups]' --output text | grep ${ELB} -A 1 | tail -n 1)
    echo "SQG: ${SQG}"
    if [[ "${SQG}" != "" ]]; then
      aws ec2 revoke-security-group-ingress --group-id ${SQG} --protocol tcp --port 80 --cidr 0.0.0.0/0
      aws ec2 revoke-security-group-ingress --group-id ${SQG} --protocol tcp --port 443 --cidr 0.0.0.0/0
      aws ec2 authorize-security-group-ingress --group-id ${SQG} --protocol tcp --port 80 --cidr 98.51.38.177/32
      aws ec2 authorize-security-group-ingress --group-id ${SQG} --protocol tcp --port 443 --cidr 98.51.38.177/32
      aws ec2 authorize-security-group-ingress --group-id ${SQG} --protocol tcp --port 80 --cidr 218.153.127.33/32
      aws ec2 authorize-security-group-ingress --group-id ${SQG} --protocol tcp --port 443 --cidr 218.153.127.33/32
      aws ec2 authorize-security-group-ingress --group-id ${SQG} --protocol tcp --port 80 --cidr jenkins.default.eks-main-t.shoptoolstest.co.kr/32
      aws ec2 authorize-security-group-ingress --group-id ${SQG} --protocol tcp --port 443 --cidr jenkins.default.eks-main-t.shoptoolstest.co.kr/32
    fi
    trace_off
#    if [[ "${ELB_NM}" != "" ]]; then
#      echo "ELB_NM: ${ELB_NM}"
#      SQG_NAME=worker_group_office
#      SQG=$(aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName]' --output text | grep worker_group_office | awk '{print $1}')
#      echo "SQG: ${SQG}"
#      ELB=$(echo ${ELB_NM} | cut -d "-" -f 1)
#      aws elb apply-security-groups-to-load-balancer --load-balancer-name ${ELB} --security-groups ${SQG}
#    fi
  fi
elif [[ "${ACTION}" == "ecs" ]]; then
  echo "#######################################"
  echo check out ${ECS_REPO}
  echo "#######################################"
  pwd
  echo sudo rm -Rf ${ECS_REPO}
  sudo rm -Rf ${ECS_REPO}
  if [[ "${STAGING}" == "prod" ]]; then
      git clone "https://${git_id}:${git_token}@bitbucket.org/seerslab/${ECS_REPO}.git"
  elif [[ "${STAGING}" == "qa" ]]; then
      git clone -b qa "https://${git_id}:${git_token}@bitbucket.org/seerslab/${ECS_REPO}.git"
  fi
  echo "# [ECS] ######################################"
  echo bash ${ECS_SH} ${APP_NAME} ${STAGING} ${TAG_ID}
  echo "#######################################"
  bash ${ECS_SH} ${APP_NAME} ${STAGING} ${TAG_ID}
  echo ${TAG_ID} > ~/${APP_NAME}-${STAGING}
elif [[ "${ACTION}" == "s3" ]]; then
  echo "#######################################"
  echo "DIST: ${DIST}"
  echo "S3_BUCKET: ${S3_BUCKET}"
  echo "DIST_DOCKER: ${DIST_DOCKER}"
  echo "CLOUDFRONT_ID: ${CLOUDFRONT_ID}"
  echo "#######################################"
  trace_on

  # aws s3 rm s3://${S3_BUCKET} --recursive
  if [[ "${DIST}" != "" && "${S3_BUCKET}" != "" ]]; then
    aws s3 cp --recursive ./${DIST}/ s3://${S3_BUCKET} --region ${AWS_REGION}
    if [[ $? != 0 ]]; then
      echo "Failed to push to s3!!!"
      alert_slack
      exit 1
    fi
  elif [[ "${DIST_DOCKER}" != "" && "${S3_BUCKET}" != "" ]]; then
    docker run -d --rm ${REPOSITORY_TAG}
    sleep 10
    DOCKER_ID=`docker ps | grep ${REPOSITORY_TAG} | awk '{print $1}'`
    docker cp ${DOCKER_ID}:${DIST_DOCKER} dist_docker
    ls -al dist_docker
    docker kill ${DOCKER_ID}
    aws s3 cp --recursive ./dist_docker/ s3://${S3_BUCKET} --region ${AWS_REGION}
    if [[ $? != 0 ]]; then
      echo "Failed to push to s3!!!"
      alert_slack
      exit 1
    fi
  fi

  if [[ "${CLOUDFRONT_ID}" != "" ]]; then
    aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_ID} --paths '/*' --region ${AWS_REGION}
    if [[ $? != 0 ]]; then
      echo "Failed to invalidate Cloudfront Cache!!!"
      alert_slack
      exit 1
    fi
  fi
  trace_off
elif [[ "${ACTION}" == "slack" ]]; then
  if [[ "${SLACK_HOOK}" == "" ]]; then
    echo "NO SLACK_HOOK!!!"
    exit 1
  fi
  trace_on
  curl -X POST -H 'Content-type: application/json' --data '{"text":"build done '${APP_NAME}': '${BUILD_URL}'"}' ${SLACK_HOOK}
  if [[ $? != 0 ]]; then
    echo "Failed to send message by slack!!!"
    alert_slack
    exit 1
  fi
  trace_off
fi

exit 0

#aws sts get-caller-identity
#aws eks --region region-code update-kubeconfig --name cluster_name


export VAULT_ADDR=https://vault.vault.svc.cluster.local:8200

CLUSTER_NAME=eks-main-t
eks_domain=default.eks-main-t.shoptoolstest.co.kr
export VAULT_ADDR=http://vault.default.${CLUSTER_NAME}.${eks_domain}
login_out=$(vault login ${vault_token})

tmp=tmp_$(shuf -i 0-1000 -n 1)
echo "" > .env
echo "" > ${tmp}
fields=($(vault kv list secret/tz-dev | tail +3))
for item in "${fields[@]}"; do
  echo "====================${item}====================" >> ${tmp}
  vault kv get secret/tz-dev/${item} | tail +13 >> ${tmp}
  echo "" >> ${tmp}
done
cat ${tmp} | tr -s ' ' | sed 's| |=|g' >> .env
cat .env && rm -Rf ${tmp}

vault kv get secret/tz-dev/database | grep -wn 'Key              Value' | cut -d':' -f1
grep -wn 'Key              Value' file | cut -d':' -f1

vault kv get -field=aws tz-dev

vault kv get tz/vault/course

vault kv list kv/tz-vault




}