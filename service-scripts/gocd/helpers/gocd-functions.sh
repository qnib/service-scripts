#!/bin/bash

: ${DOCKER_REPO:=qnib}
: ${DOCKER_TAG:=latest}
: ${FROM_IMG_TAG:=latest}

function assemble_build_img_name {
    source /opt/service-scripts/gocd/helpers/ucp.sh
    eval_docker_secrets
    # Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
    export IMG_NAME=$(echo ${GO_PIPELINE_NAME} |awk -F'[\_\.]' '{print $1}')
    if [[ "$(echo ${GO_PIPELINE_NAME} |awk -F\. '{print NF-1}')" != 0 ]];then
      IMG_TAG=$(echo ${GO_PIPELINE_NAME} |cut -d'.' -f 2-)
      if [[ "X${IMG_TAG}" != "X" ]];then
        echo  ">> GO_PIPELINE_NAME: ${GO_PIPELINE_NAME} carries tag '${IMG_TAG}'"
        DOCKER_TAG=${IMG_TAG}
        IMG_NAME=$(echo ${GO_PIPELINE_NAME} |cut -d'.' -f 1)
      fi
    fi
    if [ ! -z ${GO_REVISION} ];then
        export BUILD_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${GO_REVISION}-rev${GO_PIPELINE_COUNTER}"
    elif [ ! -z ${GO_REVISION_DOCKER} ];then
        export BUILD_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${GO_REVISION_DOCKER}-rev${GO_PIPELINE_COUNTER}"
    elif [ ! -z ${GO_REVISION_DOCKER_} ];then
        export BUILD_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${GO_REVISION_DOCKER_}-rev${GO_PIPELINE_COUNTER}"
    else
        export BUILD_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-rev${GO_PIPELINE_COUNTER}"
    fi
    echo ">> BUILD_IMG_NAME:${BUILD_IMG_NAME}"
}

function assemble_target_img_name {
    source /opt/service-scripts/gocd/helpers/ucp.sh
    eval_docker_secrets
    if [[ -z ${1} ]];then
      echo "!! >> Please provide TARGERT_NAME as argument to assemble_target_img_name()"
    fi
    # Create TARGET_IMG_NAME, which includes the git-hash and the revision of the pipeline
    export IMG_NAME=$(echo ${GO_PIPELINE_NAME} |awk -F'[\_\.]' '{print $1}')
    if [[ "$(echo ${GO_PIPELINE_NAME} |awk -F\. '{print NF-1}')" != 0 ]];then
      IMG_TAG=$(echo ${GO_PIPELINE_NAME} |cut -d'.' -f 2-)
      if [[ "X${IMG_TAG}" != "X" ]];then
        echo  ">> GO_PIPELINE_NAME: ${GO_PIPELINE_NAME} carries tag '${IMG_TAG}'"
        DOCKER_TAG=${IMG_TAG}
        IMG_NAME=$(echo ${GO_PIPELINE_NAME} |cut -d'.' -f 1)
      fi
    fi
    if [ ! -z ${GO_REVISION} ];then
        export TARGET_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${1}-${GO_REVISION}-rev${GO_PIPELINE_COUNTER}"
    elif [ ! -z ${GO_REVISION_DOCKER} ];then
        export TARGET_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${1}-${GO_REVISION_DOCKER}-rev${GO_PIPELINE_COUNTER}"
    elif [ ! -z ${GO_REVISION_DOCKER_} ];then
        export TARGET_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${1}-${GO_REVISION_DOCKER_}-rev${GO_PIPELINE_COUNTER}"
    else
        export TARGET_IMG_NAME="${DOCKER_REPO}/${IMG_NAME}:${DOCKER_TAG}-${1}-rev${GO_PIPELINE_COUNTER}"
    fi
    echo ">> TARGET_IMG_NAME:${TARGET_IMG_NAME}"
}

function query_parent {
    # figure out information about the parent
    for E in $(env);do
        if [[ "${E}" == GO_DEPENDENCY_LOCATOR_* ]];then
            export FROM_IMG_NAME=$(echo ${E} |awk -F= '{print $2}' |awk -F/ '{print $1}')
            if [[ "$(echo ${FROM_IMG_NAME} |awk -F\. '{print NF-1}')" != 0 ]];then
              export FROM_IMG_TAG=$(echo ${FROM_IMG_NAME} |cut -d'.' -f 2-)
              export FROM_IMG_NAME=$(echo ${FROM_IMG_NAME} |cut -d'.' -f 1)
              echo ">>> Derived FROM_IMG_TAG '${FROM_IMG_TAG}' from FROM_IMG_NAME: ${FROM_IMG_NAME}"
            fi
        fi
        if [[ "${E}" == GO_DEPENDENCY_LABEL_* ]];then
            export FROM_IMG_TAG=${FROM_IMG_TAG}-rev$(echo ${E} |awk -F= '{print $2}')
            echo ">>> Label added to FROM_IMG_TAG: ${FROM_IMG_TAG}"
        fi
    done
}
