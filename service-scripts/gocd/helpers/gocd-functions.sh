#!/bin/bash

export DOCKER_REPO=${DOCKER_REPO:-qnib}

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
    export PREV_PIPELINE=$(echo ${GO_DEPENDENCY_LOCATOR_PARENTTRIGGER} |awk -F/ '{print $1}')
    export QUERY_URL="${GO_SERVER_URL}/api/pipelines/${PREV_PIPELINE}/instance/${GO_DEPENDENCY_LABEL_PARENTTRIGGER}"
    export PREV_REV=$(curl -s "${QUERY_URL}" |jq ".build_cause.material_revisions[0].modifications[0].revision" |tr -d '"')
    echo ">> PREV_REV:${PREV_REV}"
}
