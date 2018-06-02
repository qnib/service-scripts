#!/bin/bash
echo ">> Publish"
set -e

: ${HOME_DIR:=/home}
: ${SKIP_TAG_LATEST:=false}
: ${DOCKER_TAG_REV:=true}

if [ -z ${DOCKER_REPO} ];then
    echo ">> Publish >>> Using ${DOCKER_REPO_DEFAULT} as DOCKER_REPO name"
    export DOCKER_REPO=${DOCKER_REPO_DEFAULT}
fi
source /opt/service-scripts/gocd/helpers/gocd-functions.sh
# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name
source /opt/service-scripts/gocd/helpers/ucp.sh
ucp_source_bundle

if [[ $(basename $(pwd)) == "docker" ]];then
    ARTIFACTS_DIR=".."
else
    ARTIFACTS_DIR="."
fi
mkdir -p ${ARTIFACTS_DIR}/target/
if [ "${SKIP_TAG_LATEST}" == "false" ];then
    echo ">> Publish >>> Tag image with '${DOCKER_TAG}': docker tag ${BUILD_IMG_NAME} ${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}"
    docker tag ${BUILD_IMG_NAME} ${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
    if [ "X${DOCKER_REG}" != "X" ];then
      echo ">> Publish >>> Push image to ${DOCKER_REG}: docker tag/push/rmi ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}"
      docker tag ${BUILD_IMG_NAME} ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
      set +e
      docker push ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
      if [[ $? -ne 0 ]];then
        echo "[!!] Push failed "
        exit 1
      fi
      set -e
      BUILD_IMG_REPODIGEST=$(docker inspect -f '{{(index .RepoDigests 0) }}' ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG} |awk -F\@ '{print $2}')
      IMG_FULL_NAME="${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}@${BUILD_IMG_REPODIGEST}"
      echo ">> Full name of image: ${IMG_FULL_NAME}"
      echo ${IMG_FULL_NAME} > ${ARTIFACTS_DIR}/target/${IMG_NAME}.image_name
      docker rmi ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
    fi
else
   echo ">> PUBLISH >>> Skip tagging the build as ${DOCKER_TAG}"
fi

if [ "${DOCKER_TAG_REV}" == "true" ];then
    BUILD_REV_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-rev${GO_PIPELINE_COUNTER}"
    echo ">> Publish >>> Tag image locally with build revision: docker tag/push/rmi ${BUILD_REV_NAME}"
    docker tag ${BUILD_IMG_NAME} ${BUILD_REV_NAME}
    if [ "X${DOCKER_REG}" != "X" ];then
        echo ">> Publish >>> Tag image remotely with build revision: docker tag/push/rmi ${DOCKER_REG}/${BUILD_REV_NAME}"
        docker tag ${BUILD_IMG_NAME} ${DOCKER_REG}/${BUILD_REV_NAME}
        docker push ${DOCKER_REG}/${BUILD_REV_NAME}
        BUILD_IMG_REPODIGEST=$(docker inspect -f '{{(index .RepoDigests 0) }}' ${DOCKER_REG}/${BUILD_REV_NAME} |awk -F\@ '{print $2}')
        IMG_FULL_NAME="${DOCKER_REG}/${BUILD_REV_NAME}@${BUILD_IMG_REPODIGEST}"
        echo ">> Full name of image: ${IMG_FULL_NAME}"
        echo ${IMG_FULL_NAME} > ${ARTIFACTS_DIR}/target/${IMG_NAME}.image_name
        docker rmi ${DOCKER_REG}/${BUILD_REV_NAME}
    fi
else
   echo ">> PUBLISH >>> Skip pushing to registry, since none set"
fi
docker rmi ${BUILD_IMG_NAME}
