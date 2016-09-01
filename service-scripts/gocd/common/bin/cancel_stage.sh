#!/bin/bash

GOCD_SERVER_URL=$(echo ${GO_SERVER_URL} |sed -e 's/https/http/')
GOCD_SERVER_URL=$(echo ${GOCD_SERVER_URL} |sed -e 's/8154/8153/')
GOCD_API_URL=$(echo ${GOCD_SERVER_URL}/api |sed -e 's#//api#/api#g')


if [ ! -z ${GOCD_CREDENTIALS} ];then
    GOCD_AUTH="-u '${GOCD_CREDENTIALS}'"
fi

if [ -z ${GO_STAGE_NAME} ];then
    echo "GO_STAGE_NAME is not set, exiting..."
    exit 0
fi
if [ -z ${GO_PIPELINE_NAME} ];then
    echo "GO_PIPELINE_NAME is not set, exiting..."
    exit 0
fi

echo ">>> curl -H 'Confirm: true' -X POST ${GOCD_API_URL}/stages/${GO_PIPELINE_NAME}/${GO_STAGE_NAME}/cancel"
curl -s "${GOCD_API_URL}/stages/${GO_PIPELINE_NAME}/${GO_STAGE_NAME}/cancel" \
      -H 'Confirm: true' \
      ${GOCD_AUTH} -X POST
