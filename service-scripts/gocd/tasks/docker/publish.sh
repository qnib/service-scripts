#!/bin/bash
echo ">> Publish"
set -e

: ${HOME_DIR:=/home}
: ${DOCKER_PUSH_DISABLE:=false}
: ${SKIP_TAG_LATEST:=false}
: ${DOCKER_TAG_REV:=true}
: ${DOCKER_REMOVE_IMAGES:=true}
: ${DOCKER_BUILD_TARGETS:=false}

if [[ "${DOCKER_PUSH_DISABLE}" == "true" ]];then
  echo ">> Push disabled by DOCKER_PUSH_DISABLE==true"
  exit 0
fi
if [ -z ${DOCKER_REPO} ];then
    echo ">> Publish >>> Using ${DOCKER_REPO_DEFAULT} as DOCKER_REPO name"
    export DOCKER_REPO=${DOCKER_REPO_DEFAULT}
fi
source /opt/service-scripts/gocd/helpers/gocd-functions.sh
# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name
source /opt/service-scripts/gocd/helpers/ucp.sh
if [[ ${DOCKER_USE_LOGIN} == "true" ]];then
  docker_login
else
  ucp_source_bundle
fi

if [[ $(basename $(pwd)) == "docker" ]];then
    ARTIFACTS_DIR=".."
else
    ARTIFACTS_DIR="."
fi
mkdir -p ${ARTIFACTS_DIR}/target/
if [ "${SKIP_TAG_LATEST}" == "false" ];then
    echo ">> Publish >>> Tag image with '${DOCKER_TAG}': docker tag ${BUILD_IMG_NAME} ${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}"
    docker tag ${BUILD_IMG_NAME} ${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
    if [ "X${DOCKER_REGISTRY}" != "X" ];then
      echo ">> Publish >>> Push image to ${DOCKER_REGISTRY}: docker tag/push/rmi ${DOCKER_REGISTRY}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}"
      docker tag ${BUILD_IMG_NAME} ${DOCKER_REGISTRY}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
      set +e
      begin=$(date +%s)
      docker push ${DOCKER_REGISTRY}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
      if [[ $? -ne 0 ]];then
        end=$(date +%s)
        if [[ $(($end-$begin)) -lt 300 ]];then
          echo "[!!] Push failed ($(($end-$begin))<300s)"
          exit 1
        else
          echo "[WW] Push failed (>300s), try once more"
          docker push ${DOCKER_REGISTRY}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
          if [[ $? -ne 0 ]];then
            echo "[!!] Push failed second time (<500s)"
            exit 1
          fi
        fi
      fi
      set -e
      BUILD_IMG_REPODIGEST=$(docker inspect -f '{{(index .RepoDigests 0) }}' ${DOCKER_REGISTRY}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG} |awk -F\@ '{print $2}')
      IMG_FULL_NAME="${DOCKER_REGISTRY}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}@${BUILD_IMG_REPODIGEST}"
      echo ">> Full name of image: ${IMG_FULL_NAME}"
      echo ${IMG_FULL_NAME} > ${ARTIFACTS_DIR}/target/${IMG_NAME}.image_name
      if [[ "${DOCKER_REMOVE_IMAGES}" == "true" ]];then
        docker rmi ${DOCKER_REGISTRY}/${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}
      fi
    fi
else
   echo ">> PUBLISH >>> Skip tagging the build as ${DOCKER_TAG}"
fi

if [ "${DOCKER_TAG_REV}" == "true" ];then
    BUILD_REV_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-rev${GO_PIPELINE_COUNTER}"
    echo ">> Publish >>> Tag image locally with build revision: docker tag/push/rmi ${BUILD_REV_NAME}"
    docker tag ${BUILD_IMG_NAME} ${BUILD_REV_NAME}
    if [ "X${DOCKER_REGISTRY}" != "X" ];then
        echo ">> Publish >>> Tag image remotely with build revision: docker tag/push/rmi ${DOCKER_REGISTRY}/${BUILD_REV_NAME}"
        docker tag ${BUILD_IMG_NAME} ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
        set +e
        begin=$(date +%s)
        docker push ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
        if [[ $? -ne 0 ]];then
          end=$(date +%s)
          if [[ $(($end-$begin)) -lt 200 ]];then
            echo "[!!] Push failed (<200s)"
            exit 1
          else
            echo "[WW] Push failed (>200s), try once more"
            docker push ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
            if [[ $? -ne 0 ]];then
              echo "[!!] Push failed second time. :("
              exit 1
            fi
          fi
        fi
        set -e
        BUILD_IMG_REPODIGEST=$(docker inspect -f '{{(index .RepoDigests 0) }}' ${DOCKER_REGISTRY}/${BUILD_REV_NAME} |awk -F\@ '{print $2}')
        IMG_FULL_NAME="${DOCKER_REGISTRY}/${BUILD_REV_NAME}@${BUILD_IMG_REPODIGEST}"
        echo ">> Full name of image: ${IMG_FULL_NAME}"
        echo ${IMG_FULL_NAME} > ${ARTIFACTS_DIR}/target/${IMG_NAME}.image_name
        if [[ "${DOCKER_REMOVE_IMAGES}" == "true" ]];then
          docker rmi ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
        fi
    fi
else
   echo ">> PUBLISH >>> Skip pushing to registry, since none set"
fi

## Push targets
if [[ "${DOCKER_BUILD_TARGETS}" != "true" ]];then
  echo ">> Skip creating target images: DOCKER_BUILD_TARGETS==false"
  exit 0
fi
echo ">> Creating target images: DOCKER_BUILD_TARGETS==true"
DFILE_TARGETS=$(grep '^FROM' ${DOCKER_FILE} | awk '/^FROM.* AS /{print $NF}' |xargs |sed -e 's/ /:/g')
for DFILE_TARGET in $(echo ${DFILE_TARGETS} |sed -e 's/:/ /g');do
  echo ">> Targets to push: ${DFILE_TARGETS}"
  assemble_target_img_name ${DFILE_TARGET}
  BUILD_REV_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${DFILE_TARGET}-rev${GO_PIPELINE_COUNTER}"
  echo ">> Publish >>> Tag image locally with build revision: docker tag/push/rmi ${BUILD_REV_NAME}"
  docker tag ${BUILD_IMG_NAME} ${BUILD_REV_NAME}
  if [ "X${DOCKER_REGISTRY}" != "X" ];then
      echo ">> Publish >>> Tag image remotely with build revision: docker tag/push/rmi ${DOCKER_REGISTRY}/${BUILD_REV_NAME}"
      docker tag ${BUILD_IMG_NAME} ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
      set +e
      begin=$(date +%s)
      docker push ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
      if [[ $? -ne 0 ]];then
          end=$(date +%s)
          if [[ $(($end-$begin)) -lt 200 ]];then
            echo "[!!] Push failed (<200s)"
            exit 1
          else
            echo "[WW] Push failed (>200s), try once more"
            docker push ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
            if [[ $? -ne 0 ]];then
              echo "[!!] Push failed second time. :("
              exit 1
            fi
          fi
      fi
      set -e
      BUILD_IMG_REPODIGEST=$(docker inspect -f '{{(index .RepoDigests 0) }}' ${DOCKER_REGISTRY}/${BUILD_REV_NAME} |awk -F\@ '{print $2}')
      IMG_FULL_NAME="${DOCKER_REGISTRY}/${BUILD_REV_NAME}@${BUILD_IMG_REPODIGEST}"
      echo ">> Full name of image: ${IMG_FULL_NAME}"
      echo ${IMG_FULL_NAME} > ${ARTIFACTS_DIR}/target/${IMG_NAME}.image_name
      if [[ "${DOCKER_REMOVE_IMAGES}" == "true" ]];then
        docker rmi ${DOCKER_REGISTRY}/${BUILD_REV_NAME}
      fi
  fi
  if [[ "${DOCKER_REMOVE_IMAGES}" == "true" ]];then
    ${TARGET_IMG_NAME}
  fi
done
if [[ "${DOCKER_REMOVE_IMAGES}" == "true" ]];then
  docker rmi ${BUILD_IMG_NAME}
fi
