#!/bin/bash

PNAME=$(echo ${GO_PIPELINE_NAME} |sed -e "s/${GO_ENVIRONMENT_NAME}-//")

cd ${PNAME}
if [[ -x ./deploy.sh ]];then
    ./deploy.sh
fi
