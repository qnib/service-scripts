#!/bin/bash
set -e

echo ">> BUILD"
: ${DOCKER_NO_CACHE:=true}
: ${DOCKER_FORCE_PULL:=true}
: ${DOCKER_REPO:=qnib}
: ${DOCKER_REGISTRY:=docker.io}

source /opt/service-scripts/gocd/helpers/ucp.sh
ucp_source_bundle

source /opt/service-scripts/gocd/helpers/gocd-functions.sh

if [[ "${DOCKER_NO_CACHE}" == "true" ]];then
    DOCKER_BUILD_OPTS="--no-cache"
else
    DOCKER_BUILD_OPTS=""
fi
if [[ "${DOCKER_FORCE_PULL}" == "true" ]];then
  DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --pull"
fi

# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name

# figure out information about the parent
query_parent
mkdir -p target/
rm -f target/build.env
for E in $(env);do
    echo export $(echo ${E} |sed -e 's/ /_/g') >> target/build.env
    if [[ "${E}" == DBUILD_* ]];then
      DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=$(echo ${E}|sed -e 's/DBUILD_//')"
    fi
done
#### TODO: Put the vars in a set, so that they can be overwritten
if [[ "X${FROM_IMG_REGISTRY}" != "X" ]];then
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=FROM_IMG_REGISTRY=${FROM_IMG_REGISTRY}"
fi
if [[ "X${FROM_IMG_NAME}" != "X" ]];then
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=FROM_IMG_NAME=${FROM_IMG_NAME}"
fi
if [[ "X${FROM_IMG_TAG}" != "X" ]];then
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=FROM_IMG_TAG=${FROM_IMG_TAG}"
fi
if [[ "X${DOCKER_REPO}" != "X" ]];then
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=DOCKER_REPO=${DOCKER_REPO}"
fi
if [[ "X${DOCKER_REGISTRY}" != "X" ]];then
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=DOCKER_REGISTRY=${DOCKER_REGISTRY}"
fi

if [ -d docker ];then
    cd docker
fi
if [[ -d deploy/docker/ ]];then
    rsync -aP deploy/docker/. .
fi

echo ">> BUILD >>> Add DOCKER_REG to Dockerfile"
REG_IMG_NAME=$(grep ^FROM Dockerfile | awk '{print $2}')
if [ $(echo ${REG_IMG_NAME} | grep -o "/" | wc -l) -gt 1 ];then
    echo ">> BUILD >>>> Sure you wanna add the registry? Looks not right: ${REG_IMG_NAME}"
elif [ $(echo ${REG_IMG_NAME} | grep -o "/" | wc -l) -eq 0 ];then
    echo ">> BUILD >>>> Image is an official one, so we skip it '${REG_IMG_NAME}'"
else
    if [ "X${DOCKER_REG}" != "X" ];then
        cat Dockerfile |sed -e "s;FROM.*;FROM ${DOCKER_REG}/${REG_IMG_NAME};" > Dockerfile.new
        mv Dockerfile.new Dockerfile
        docker pull ${DOCKER_REG}/${REG_IMG_NAME}
     fi
fi

echo ">> BUILD >>> Build Dockerfile: docker build ${DOCKER_BUILD_OPTS} -t ${BUILD_IMG_NAME} ."
docker build ${DOCKER_BUILD_OPTS} -t ${BUILD_IMG_NAME} .
