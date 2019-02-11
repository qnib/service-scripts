#!/bin/bash
set -e

echo ">> BUILD"
: ${DOCKER_NO_CACHE:=true}
: ${DOCKER_FORCE_PULL:=true}
: ${DOCKER_SQUASH:=false}
: ${DOCKER_REPO:=qnib}
: ${DOCKER_REGISTRY:=docker.io}
: ${DOCKER_FILE:=Dockerfile}
: ${DOCKER_BUILD_LOCAL:=false}
: ${DOCKER_CONTEXT:=.}
: ${DOCKER_USE_LOGIN:=false}
: ${DOCKER_EXTEND_PLATFORM_FEATURE:=false}


source /opt/service-scripts/gocd/helpers/ucp.sh
if [[ ${DOCKER_USE_LOGIN} == "true" ]];then
  docker_login
else
  ucp_source_bundle
fi
source /opt/service-scripts/gocd/helpers/gocd-functions.sh

if [[ "${DOCKER_NO_CACHE}" == "true" ]];then
    DOCKER_BUILD_OPTS="--no-cache"
else
    DOCKER_BUILD_OPTS=""
fi
if [[ "${DOCKER_FORCE_PULL}" == "true" ]];then
  DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --pull"
fi

if [[ "${DOCKER_SQUASH}" == "true" ]];then
  DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --squash"
fi

if [[ ${DOCKER_USE_LOGIN} != "true" ]] && [[ "${DOCKER_BUILD_LOCAL}" == "true" ]] && [[ "${DOCKER_NO_CACHE}" != "true" ]];then
  DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg constraint:node==$(cat ~/docker-node)"
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
      KV_PAIR=$(echo ${E}|sed -e 's/DBUILD_//')
      DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=${KV_PAIR}"
      KEY=$(echo ${KV_PAIR} |cut -d\= -f 1)
      VALUE=$(echo ${KV_PAIR} |cut -d\= -f 2-)
      echo ">> declare ${KEY}=${VALUE}"
      declare ${KEY}=${VALUE}
    fi
done

#### TODO: Put the vars in a set, so that they can be overwritten
if [[ "X${FROM_IMG_REGISTRY}" != "X" ]];then
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=FROM_IMG_REGISTRY=${FROM_IMG_REGISTRY}"
fi
if [[ "X${FROM_IMG_NAME}" != "X" ]];then
    if [[ "$(echo ${FROM_IMG_NAME} |awk -F\. '{print NF-1}')" != 0 ]];then
      FROM_IMG_NAME=$(echo ${FROM_IMG_NAME} |cut -d'.' -f 1)
    fi
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
if [[ "X${DOCKER_FILE}" != "X" ]];then
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} -f=${DOCKER_FILE}"
fi
if [ -d docker ];then
    echo ">> Change dir to docker"
    cd docker
fi
if [[ -d deploy/docker/ ]];then
    rsync -aP deploy/docker/. .
fi

#### Figure out FROM_IMG_* to eval name at the end

if [[ "X${FROM_IMG_REPO}" == "X" ]];then
    FROM_IMG_REPO=$(grep '^ARG FROM_IMG_REPO=' ${DOCKER_FILE} | cut -d\= -f 2 |sed -e 's/\"//g')
    echo ">> Derived FROM_IMG_REPO via Dockerfile: ${FROM_IMG_REPO}"
fi
if [[ "X${FROM_IMG_NAME}" == "X" ]];then
    FROM_IMG_NAME=$(grep '^ARG FROM_IMG_NAME=' ${DOCKER_FILE} | cut -d\= -f 2 |sed -e 's/\"//g')
    echo ">> Derived FROM_IMG_NAME via Dockerfile: ${FROM_IMG_NAME}"
fi
if [[ "X${FROM_IMG_TAG}" == "X" ]];then
    FROM_IMG_TAG=$(grep '^ARG FROM_IMG_TAG=' ${DOCKER_FILE} | cut -d\= -f 2 |sed -e 's/\"//g')
    echo ">> Derived FROM_IMG_TAG via Dockerfile: ${FROM_IMG_TAG}"
fi

#### Figure out FROM statement that creates the output image
if [[ "X${DOCKER_EXTEND_PLATFORM_FEATURE}" == "Xtrue" ]];then
  DFILE_FROM_IMAGE=$(grep '^FROM' ${DOCKER_FILE} | grep -v ' AS ' |tail -n1 |sed -e 's/^FROM\ //g')

  if [[ "X${DFILE_FROM_IMAGE}" == "X" ]];then
    echo ">> ERROR: Could not find FROM statement in Dockerfile without AS condition"
    exit 1
  fi
  echo ">> Found FROM: ${DFILE_FROM_IMAGE}"
  EVAL_FROM_NAME="echo ${DFILE_FROM_IMAGE}"
  DFILE_FROM_IMAGE=$(eval ${EVAL_FROM_NAME})
  echo ">> FROM after eval: ${DFILE_FROM_IMAGE}"
  echo ">> Download FROM image: ${DFILE_FROM_IMAGE})"
  docker pull ${DFILE_FROM_IMAGE}
  echo ">> Check for platform.features label in ${DFILE_FROM_IMAGE}"
  PFEATURE_PRE=$(docker image inspect ${DFILE_FROM_IMAGE} |jq -r '.[0] | .ContainerConfig.Labels["platform.features"]')
  if [[ "X{$PFEATURE_PRE}" != 'X<no value>' ]] && [[ "X{$PFEATURE_PRE}" != 'X' ]];then
    echo ">> Found platform.features: ${PFEATURE_PRE}"
    if [[ "X${PLATFORM_FEATURES}" != "X" ]];then
      NEW_PLATFORM_FEATURES=$(echo "${PFEATURE_PRE},${PLATFORM_FEATURES}" |sed -e 's/,/ /g'|xargs -n1 |sort -u |xargs |sed -e 's/ /,/g')
      echo ">> Extend platform.features with '${PLATFORM_FEATURES}' to: '${NEW_PLATFORM_FEATURES}'"
      DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --label platform.features=${NEW_PLATFORM_FEATURES}"
    fi
  fi
  if [[ "X${CFLAG_MARCH}" == "X" ]];then
    CFLAG_MARCH=$(docker image inspect ${DFILE_FROM_IMAGE} |jq -r '.[0] | .ContainerConfig.Labels["cflag.march"]')
    DOCKER_BUILD_OPTS="${DOCKER_BUILD_OPTS} --build-arg=CFLAG_MARCH=${CFLAG_MARCH}"
  fi
fi

#echo ">> BUILD >>> Add DOCKER_REG to Dockerfile"
#REG_IMG_NAME=$(grep ^FROM Dockerfile | awk '{print $2}')
#if [ $(echo ${REG_IMG_NAME} | grep -o "/" | wc -l) -gt 1 ];then
#    echo ">> BUILD >>>> Sure you wanna add the registry? Looks not right: ${REG_IMG_NAME}"
#elif [ $(echo ${REG_IMG_NAME} | grep -o "/" | wc -l) -eq 0 ];then
#    echo ">> BUILD >>>> Image is an official one, so we skip it '${REG_IMG_NAME}'"
#else
#    if [ "X${DOCKER_REG}" != "X" ];then
#        cat Dockerfile |sed -e "s;FROM.*;FROM ${DOCKER_REG}/${REG_IMG_NAME};" > Dockerfile.new
#        mv Dockerfile.new Dockerfile
#        docker pull ${DOCKER_REG}/${REG_IMG_NAME}
#     fi
#fi
echo ">> PWD: $(pwd)"
echo ">> BUILD >>> Build Dockerfile: docker build ${DOCKER_BUILD_OPTS} -t ${BUILD_IMG_NAME} ${DOCKER_CONTEXT}"
docker build ${DOCKER_BUILD_OPTS} -t ${BUILD_IMG_NAME} ${DOCKER_CONTEXT}
