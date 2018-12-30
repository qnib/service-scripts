#!/bin/bash
set -e

echo ">> RUN"
: ${DOCKER_REPO:=qnib}
: ${DOCKER_REGISTRY:=docker.io}
: ${DOCKER_USE_LOGIN:=false}

source /opt/service-scripts/gocd/helpers/ucp.sh
if [[ ${DOCKER_USE_LOGIN} == "true" ]];then
  docker_login
else
  ucp_source_bundle
fi
source /opt/service-scripts/gocd/helpers/gocd-functions.sh

# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name

# figure out information about the parent
query_parent

echo ">> docker run $@"
docker run $@
