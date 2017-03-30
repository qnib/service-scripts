#!/bin/bash

export DEPLOY_NAME=$(echo ${GO_PIPELINE_NAME} |awk -F\- '{print $2}')
if [[ ! -d ${DEPLOY_NAME} ]];then
  exit 1
fi
cd ${DEPLOY_NAME}
if [[ -x predeploy.sh ]];then
  ./predeploy.sh
fi
docker stack deploy --compose-file docker-compose.yml ${DEPLOY_NAME}
