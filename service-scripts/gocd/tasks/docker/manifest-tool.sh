#!/bin/bash
set -e

echo ">> RUN"
: ${DOCKER_REPO:=qnib}
: ${DOCKER_USE_LOGIN:=false}
: ${DOCKER_REGISTRY_INSECURE:=false}
: ${MANIFESTTOOL_OPTS}
source /opt/service-scripts/gocd/helpers/ucp.sh
eval_docker_secrets
if [[ ${DOCKER_USE_LOGIN} == "true" ]];then
  docker_login
else
  ucp_source_bundle
fi
source /opt/service-scripts/gocd/helpers/gocd-functions.sh


if [[ "${DOCKER_REGISTRY_INSECURE}" == "true" ]];then
  MANIFESTTOOL_OPTS="${MANIFESTTOOL_OPTS} --insecure"
fi

# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name

echo "image: ${DOCKER_REGISTRY}/${BUILD_IMG_NAME}" |tee manifest.yml
echo "manifests:" |tee -a manifest.yml
for x in $(env |sort -r |grep GO_DEPENDENCY);do
  if [[ $x == *"GO_DEPENDENCY_LOCATOR"* ]];then
    DEPENDENCY_VAR=$(echo "$x" |awk -F= '{print $2}')
    echo ">> DEPENDENCY_VAR: ${DEPENDENCY_VAR}"
    DEPENDENCY_PIPE_NAME=$(echo ${DEPENDENCY_VAR} | awk -F/ '{print $1}')
    echo ">> DEPENDENCY_PIPE_NAME: ${DEPENDENCY_PIPE_NAME}"
    if [[ $(echo ${DEPENDENCY_PIPE_NAME} |awk -F. '{print NF-1}') -ge 1 ]];then
      DEPENDENCY_TAG_NAME=$(echo ${DEPENDENCY_PIPE_NAME} |cut -d\. -f 2-)
      DEPENDENCY_DOCKER_IMAGE=$(echo ${DEPENDENCY_PIPE_NAME} | awk -F\. '{print $1}')
    else
      DEPENDENCY_TAG_NAME=latest
      DEPENDENCY_DOCKER_IMAGE=$(echo ${DEPENDENCY_PIPE_NAME})
    fi
    echo ">> DEPENDENCY_TAG_NAME: ${DEPENDENCY_TAG_NAME}"
    echo ">> DEPENDENCY_DOCKER_IMAGE: ${DEPENDENCY_DOCKER_IMAGE}"
    DEPENDENCY_IMAGE_NAME=${DOCKER_REGISTRY}/${DOCKER_REPO}/${DEPENDENCY_DOCKER_IMAGE}:${DEPENDENCY_TAG_NAME}
    DEPENDENCY_BUILD_TAG_NAME=(GO_DEPENDENCY_LABEL_$(echo ${DEPENDENCY_DOCKER_IMAGE}|tr '[:lower:]' '[:upper:]' |tr '-' '_'))
    if [[ ${DEPENDENCY_TAG_NAME} != "latest" ]];then
      DEPENDENCY_BUILD_TAG_NAME=(${DEPENDENCY_BUILD_TAG_NAME}_$(echo ${DEPENDENCY_TAG_NAME} |tr '[:lower:]' '[:upper:]' |tr '\.' '_'))
    fi
    echo ">> DEPENDENCY_BUILD_TAG_NAME: ${DEPENDENCY_BUILD_TAG_NAME}"
    DEPENDENCY_IMAGE_NAME=$(eval echo "${DEPENDENCY_IMAGE_NAME}-rev\$$DEPENDENCY_BUILD_TAG_NAME")
    echo ">> DEPENDENCY_IMAGE_NAME: ${DEPENDENCY_IMAGE_NAME}"
    docker pull ${DEPENDENCY_IMAGE_NAME}
    DEPENDENCY_FEATURES=$(docker image inspect ${DEPENDENCY_IMAGE_NAME}|jq -r '.[] |.Config.Labels["platform.features"]')
    echo ">> DEPENDENCY_FEATURES: ${DEPENDENCY_FEATURES}"
    echo "  -" |tee -a manifest.yml
    echo "    image: ${DEPENDENCY_IMAGE_NAME}" |tee -a manifest.yml
    echo "    platform:" |tee -a manifest.yml
    echo "      architecture: amd64" |tee -a manifest.yml
    echo "      os: linux" |tee -a manifest.yml
    if [[ "X${DEPENDENCY_FEATURES}" != "Xnull" ]];then
      echo "      features:" |tee -a manifest.yml
      for DEPENDENCY_FEATURE in $(echo ${DEPENDENCY_FEATURES} |sed -e 's/,/ /g');do
        echo "        - ${DEPENDENCY_FEATURE}" |tee -a manifest.yml
      done
    fi
  fi
done
echo ">> Manifest to be pushed"
cat manifest.yml
echo ">> manifest-tool push from-spec manifest.yml"
manifest-tool ${MANIFESTTOOL_OPTS} push from-spec manifest.yml
echo ">> manifest-tool inspect ${DOCKER_REGISTRY}/${BUILD_IMG_NAME}"
manifest-tool ${MANIFESTTOOL_OPTS} inspect ${DOCKER_REGISTRY}/${BUILD_IMG_NAME}
