#!/bin/bash

: ${DOCKER_REPO:=qnib}
: ${DOCKER_TAG:=latest}

function assemble_build_img_name {
    # Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
    export IMG_NAME=$(echo ${GO_PIPELINE_NAME} |awk -F'[\_\.]' '{print $1}')
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

function query_parent {
    # figure out information about the parent
    for E in $(env);do
        if [[ "${E}" == GO_DEPENDENCY_LOCATOR_* ]];then
            export FROM_IMG_NAME=$(echo ${E} |awk -F= '{print $2}' |awk -F/ '{print $1}')
        fi
        if [[ "${E}" == GO_DEPENDENCY_LABEL_* ]];then
            export FROM_IMG_TAG=${DOCKER_TAG}-rev$(echo ${E} |awk -F= '{print $2}')
        fi
    done
}
