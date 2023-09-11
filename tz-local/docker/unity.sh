#!/usr/bin/env bash
#set -x

# vi /root/shared-data/unity.sh

#export UNITY_SERIAL_KEY=xxxx
#export UNITY_USERNAME=devops@seerslab.com
#export UNITY_PASSWORD='xxxx'
#export GIT_USER=dooheehong
#export GIT_PASSWD=xxxx
#export UNITY_VERSION=2021.3.29f1
#export BUILD_TARGET=Android
#export BUILD_NAME=unity_ci_test
#export BUILD_BRANCH=devops
#bash /root/shared-data/unity.sh

echo "UNITY_SERIAL_KEY: $UNITY_SERIAL_KEY"
echo "UNITY_PASSWORD: $UNITY_PASSWORD"
echo "GIT_USER: $GIT_USER"
echo "GIT_PASSWD: $GIT_PASSWD"
echo "BUILD_NAME: $BUILD_NAME"
echo "UNITY_VERSION: $UNITY_VERSION"
echo "BUILD_BRANCH: $BUILD_BRANCH"
echo "BUILD_TARGET: $BUILD_TARGET"
echo "ANDROID_KEYSTORE_BASE64: $ANDROID_KEYSTORE_BASE64"

cd /root/shared-data
rm -Rf ${BUILD_NAME}
export GIT_DISCOVERY_ACROSS_FILESYSTEM=1
git clone https://${GIT_USER}:${GIT_PASSWD}@bitbucket.org/seerslab/${BUILD_NAME}.git
cd ${BUILD_NAME}
git checkout -b ${BUILD_BRANCH} origin/${BUILD_BRANCH}

alias ll='ls -al'
ln -s /root/shared-data/${BUILD_NAME} /app

cd /app

export BITBUCKET_CLONE_DIR=/app
export BUILD_PATH=$BITBUCKET_CLONE_DIR/Builds/$BUILD_TARGET/
mkdir -p $BUILD_PATH

android_keystore_destination=keystore.keystore
if [[ "${BUILD_TARGET}" == "Android" ]]; then
  if [[ "${ANDROID_KEYSTORE_BASE64}" != "" ]]; then
      echo "'\$ANDROID_KEYSTORE_BASE64' found, decoding content into ${android_keystore_destination}"
      echo $ANDROID_KEYSTORE_BASE64 | base64 --decode > ${android_keystore_destination}
#      ANDROID_KEYSTORE_BASE64=`cat tz-devops.jks | openssl base64 -A`
  fi
fi

UNITY_EXECUTABLE=/usr/bin/unity-editor
${UNITY_EXECUTABLE} \
  -projectPath $BITBUCKET_CLONE_DIR \
  -quit \
  -nographics \
  -username "$UNITY_USERNAME" \
  -password "$UNITY_PASSWORD" \
  -buildTarget $BUILD_TARGET \
  -serial "$UNITY_SERIAL_KEY" \
  -customBuildTarget $BUILD_TARGET \
  -customBuildName $BUILD_NAME \
  -customBuildPath $BUILD_PATH \
  -executeMethod BuildCommand.PerformBuild \
  -logFile /dev/stdout

UNITY_EXIT_CODE=$?

if [ $UNITY_EXIT_CODE -eq 0 ]; then
  echo "Run succeeded, no failures occurred";
elif [ $UNITY_EXIT_CODE -eq 2 ]; then
  echo "Run succeeded, some tests failed";
elif [ $UNITY_EXIT_CODE -eq 3 ]; then
  echo "Run failure (other failure)";
else
  echo "Unexpected exit code $UNITY_EXIT_CODE";
fi

ls -la $BUILD_PATH
[ -n "$(ls -A $BUILD_PATH)" ] # fail job if build folder is empty

pwd
echo "UNITY_EXIT_CODE: ${UNITY_EXIT_CODE}";
#sleep 500

if [[ "${UNITY_EXIT_CODE}" != "3" ]]; then
  export HOSTNAME=`hostname`
  export DATE=`date +%Y%m%d_%H%M%S`
  apk_name="${BUILD_NAME}_${BUILD_BRANCH}_${UNITY_VERSION}_${BUILD_TARGET}_${HOSTNAME}${DATE}"
  echo aws s3 cp /app/Builds/Android/${BUILD_NAME}.apk "s3://devops-unity-eks-main-t/${apk_name}.apk"
  aws s3 cp /app/Builds/Android/${BUILD_NAME}.apk "s3://devops-unity-eks-main-t/${apk_name}.apk"
  sleep 5
  exit 0
else
  exit 1
fi
