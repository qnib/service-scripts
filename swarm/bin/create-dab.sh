#!/bin/bash

set -e

CNT_COM=$(find service-orchestration)
if [ -z $1 ];then
    echo "!! Please specify a service name (path to search for the docker-compose file)"
    exit 1
fi

mkdir -p target/

cp service-orchestration/${1}/docker-compose.yml target/docker-compose-${GO_PIPELINE_COUNTER}.yml
COMPOSE_FILE=target/docker-compose-${GO_PIPELINE_COUNTER}.yml
DEV_FILE=target/dev-compose-${GO_PIPELINE_COUNTER}.yml
cp ${COMPOSE_FILE} ${DEV_FILE}

if [ -f ./service-orchestration/${1}/base.yml ];then
  cp ./service-orchestration/${1}/base.yml ./target/
fi


echo ">> Pull stack"
docker-compose -f ${COMPOSE_FILE} pull
echo ">> Bundle stack"
docker-compose -f ${COMPOSE_FILE} bundle -o target/${1}.dab

set -x
for srv in $(jq '.Services  | keys[]' target/${1}.dab |tr -d '"' |xargs);do
  printf "# %-20s\n" ${srv}
  IMG=$(jq ".Services.${srv}.Image" target/${1}.dab |tr -d '"')

  cat ${DEV_FILE} |sed -e "s#image:.*${srv}.*#image: ${IMG}#" > tmp.yml
  mv tmp.yml ${DEV_FILE}
done
