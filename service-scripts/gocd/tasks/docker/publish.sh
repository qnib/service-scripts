#!/bin/bash
echo ">> Publish"
set -e

if [ -z ${DOCKER_REPO} ];then
    echo ">> Publish >>> Using ${DOCKER_REPO_DEFAULT} as DOCKER_REPO name"
    export DOCKER_REPO=${DOCKER_REPO_DEFAULT}
fi
source /opt/service-scripts/gocd/helpers/gocd-functions.sh
# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name


if [ "X${SKIP_TAG_LATEST}" != "Xtrue" ];then
    echo ">> Publish >>> Tag image with '${DOCKER_TAG}': docker tag ${BUILD_IMG_NAME} ${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}"
    docker tag ${BUILD_IMG_NAME} ${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
    if [ "X${DOCKER_REG}" != "X" ];then
      echo ">> Publish >>> Push image to ${DOCKER_REG}: docker tag/push/rmi ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}"
      docker tag ${BUILD_IMG_NAME} ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
      docker push ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
      docker rmi ${DOCKER_REG}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
    fi
else
   echo ">> PUBLISH >>> Skip tagging the build as ${DOCKER_TAG}"
fi

if [ "X${DOCKER_TAG_REV}" == "Xtrue" ];then
    BUILD_REV_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-rev${GO_PIPELINE_COUNTER}"
    echo ">> Publish >>> Tag image locally with build revision: docker tag/push/rmi ${BUILD_REV_NAME}"
    docker tag ${BUILD_IMG_NAME} ${BUILD_REV_NAME}
    if [ "X${DOCKER_REG}" != "X" ];then
        echo ">> Publish >>> Tag image remotely with build revision: docker tag/push/rmi ${DOCKER_REG}/${BUILD_REV_NAME}"
        docker tag ${BUILD_IMG_NAME} ${DOCKER_REG}/${BUILD_REV_NAME}
        docker push ${DOCKER_REG}/${BUILD_REV_NAME}
        docker rmi ${DOCKER_REG}/${BUILD_REV_NAME}
    fi
else
   echo ">> PUBLISH >>> Skip pushing to registry, since none set"
fi
docker rmi ${BUILD_IMG_NAME}
