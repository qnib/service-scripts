#!/bin/bash

set -ex

CNT_COM=$(find service-orchestration)
if [ -z $1 ];then
    echo "!! Please specify a service name (path to search for the docker-compose file)"
    exit 1
fi

mkdir -p target/


export COMPOSE_FILE=target/docker-compose-${GO_PIPELINE_COUNTER}.yml
cp service-orchestration/${1}/docker-compose.yml ${COMPOSE_FILE}
export DEV_FILE=target/dev-compose-${GO_PIPELINE_COUNTER}.yml
export DAB_FILE="target/$(echo ${1} |sed -e 's#/#_#g').dab"

if [ -f ./service-orchestration/${1}/base.yml ];then
  cp ./service-orchestration/${1}/base.yml ./target/
fi
cp ${COMPOSE_FILE} ${DEV_FILE}

if [ -f ./service-orchestration/${1}/postdeploy.sh ];then
  cp ./service-orchestration/${1}/postdeploy.sh ./target/
fi
if [ -f ./service-orchestration/${1}/predeploy.sh ];then
  cp ./service-orchestration/${1}/predeploy.sh ./target/
fi

if [ -f ./service-orchestration/${1}/prebundle.sh ];then
  ./service-orchestration/${1}/prebundle.sh
fi

echo ">> Pull stack"
docker-compose -f ${COMPOSE_FILE} pull
echo ">> Bundle stack"
docker-compose -f ${COMPOSE_FILE} bundle -o ${DAB_FILE}

if [ -f ./service-orchestration/${1}/postbundle.sh ];then
  ./service-orchestration/${1}/postbundle.sh
fi
