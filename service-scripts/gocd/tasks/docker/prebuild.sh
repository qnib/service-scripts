#!/bin/bash
echo ">> Prebuild"
set -e

source /opt/service-scripts/gocd/helpers/gocd-functions.sh
# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name

if [ -d docker ];then
    if [ -d build_src ];then
        echo ">> cp -r build_src docker/"
        cp -r build_src docker/
    fi
    cd docker
fi


if [ -x prebuild.sh ];then
    echo ">>>> Run prebuild script"
    ./prebuild.sh
fi
