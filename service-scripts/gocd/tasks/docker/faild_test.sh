#!/bin/bash
echo ">> Since the test has failed"
set -e

source /opt/service-scripts/gocd/helpers/gocd-functions.sh
# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name


IMG_NAME=$(echo ${GO_PIPELINE_NAME} |awk -F'[\_\.]' '{print $1}')

if [ -d docker ];then
    cd docker
fi


if [ -d test ];then
    cd test
    if [ -x stop.sh ];then
        ./stop.sh
    fi
fi
docker rmi ${BUILD_IMG_NAME}
exit 1
