#!/bin/bash
echo ">> postbuild"
set -e

source /opt/service-scripts/gocd/helpers/gocd-functions.sh
# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name

mkdir -p binpkg

if [ -d docker ];then
    DOCKER_DIR=true
fi


if [ -x postbuild.sh ];then
    echo ">>>> Run postbuild script"
    if [ -d docker ];then
        ./docker/postbuild.sh
    else
        ./postbuild.sh
    fi
fi

if [ "${GOCD_LOCAL_DOCKERENGINE}" != "true" ] && [ "${GOCD_CLEAN_IMAGES}" == "true" ];then
    echo "> Remove unstarted containers"
    docker rm $(docker ps -qa)
    echo "> Remove unused images"
    docker rmi $(docker images -qa)
fi


