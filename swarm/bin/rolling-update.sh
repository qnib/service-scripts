#!/bin/bash

GOCD_SERVER_URL=$(echo ${GO_SERVER_URL} |sed -e 's/https/http/')
export GOCD_SERVER_URL=$(echo ${GOCD_SERVER_URL} |sed -e 's/8154/8153/')

mkdir -p target
for dep in $(python -c 'import os; print " ".join([item for item in os.environ if item.startswith("GO_DEPENDENCY_LOCATOR_")])');do
  printf "%-20s\n" ${dep}
  for item in $(curl -s ${GOCD_SERVER_URL}files/${!dep}/defaultJob.json  |jq '.[].files[].url' |tr -d '"');do
    fname=$(echo ${item} |awk -F/ '{print $NF}')
    curl -so target/${fname} ${item}
  done
done

COMPOSE_FILE=$(find target -name "docker-compose*.yml")
echo ">> COMPOSE_FILE=${COMPOSE_FILE}"
DAB_FILE=$(find target -name "*.dab")
echo ">> DAB_FILE=${DAB_FILE}"

cancel_counter=0
srv_counter=$(egrep -c "[a-z\-]+:\s+\#[0-9]+" ${COMPOSE_FILE})
for srv in $(egrep -o "[a-z\-]+:\s+\#[0-9]+" ${COMPOSE_FILE} |sed -e 's/ /_/g');do
  SERVICE_SCALE=$(echo ${srv} |awk -F\:\_\# '{print $2}')
  SERVICE_NAME=$(echo ${srv} |awk -F\:\_\# '{print $1}')
  echo ">> Looking into Service '${SERVICE_NAME}', expected scale '${SERVICE_SCALE}'"

  CUR_SVC_IMG=$(docker service ls |grep ${SRV_PREFIX:-qnib}_${SERVICE_NAME}|awk '{print $4}')
  if [ "X${CUR_SVC_IMG}" != "X" ];then
    CUR_SVC_CNT=$(docker service ps --filter desired-state=running ${SRV_PREFIX:-qnib}_${SERVICE_NAME} |grep -c ${SRV_PREFIX:-qnib}_${SERVICE_NAME})
    CUR_SVC_SHA=$(echo ${CUR_SVC_IMG} |awk -F'sha256:' '{print $2}')
    echo ">>>>> Current IMG '$(echo ${CUR_SVC_IMG} |awk -F\: '{print $1}')', current SHA '${CUR_SVC_SHA:0:13}'"
  fi
  LATEST_SVC_IMG=$(jq ".Services.${SERVICE_NAME}.Image" ${DAB_FILE} |tr -d '"')
  LATEST_SVC_SHA=$(echo ${LATEST_SVC_IMG} |awk -F'sha256:' '{print $2}')
  SVC_PORT=$(jq ".Services.${SERVICE_NAME}.Ports[0].Port" ${DAB_FILE})
  echo ">>>>> Dab file wants IMG '$(echo ${LATEST_SVC_IMG}|awk -F\: '{print $1}')' with SHA '${LATEST_SVC_SHA:0:13}' on exposed port ${SVC_PORT}"

  if [ "X${CUR_SVC_IMG}" == "X" ];then
    echo "XXX No stack running, deploy dab file using docker service (as docker deploy is still experimental)"
    set -ex
    SRV_ENV="$(jq '.Services.${SERVICE_NAME}.Env[]' ${DAB_FILE} |tr -d '"')"
    if [ "X${SRV_ENV}" != "X" ];then
      SRV_ENV="-e $(echo ${SRV_ENV} |sed -e 's/^/-e /' |xargs)"
    else
      SRV_ENV=""
    fi
    set -ex
    docker service create --name ${SRV_PREFIX:-qnib}_${SERVICE_NAME} ${SRV_ENV} \
                          --replicas=${SERVICE_SCALE} \
                          --publish ${SVC_PORT}:${SVC_PORT} \
                          ${LATEST_SVC_IMG}
    set +ex
  elif [ ${CUR_SVC_SHA} != ${LATEST_SVC_SHA} ] || [ "X${DOCKER_FORCE_UPDATE}" == "Xtrue" ];then
    if [ "X${DOCKER_FORCE_UPDATE}" == "Xtrue" ] && [ ${CUR_SVC_SHA} == ${LATEST_SVC_SHA} ];then
       echo "XXX DOCKER_FORCE_UPDATE=${DOCKER_FORCE_UPDATE} ; force update"
    else
       echo "XXX Cur:${CUR_SVC_SHA:0:13} != ${LATEST_SVC_SHA:0:13} ; need to update"
    fi
    set -ex
    docker service update --image=${LATEST_SVC_IMG} \
                          --replicas=${SERVICE_SCALE} \
                          --update-parallelism=1 \
                          --update-delay=${DOCKER_UPDATE_DELAY:-30s} ${SRV_PREFIX:-qnib}_${SERVICE_NAME}
    set +ex
  elif [ ${SERVICE_SCALE} -ne ${CUR_SVC_CNT} ];then
    echo "XXX Service not at the right scale 'Desired:${SERVICE_SCALE} -ne Current:${CUR_SVC_CNT}'"
    set -ex
    docker service update --replicas=${SERVICE_SCALE} --update-parallelism=1 \
                          --update-delay=${DOCKER_UPDATE_DELAY:-30s} ${SRV_PREFIX:-qnib}_${SERVICE_NAME}
    set +ex
  else
    echo "XXX ${CUR_SVC_SHA:0:13} == ${LATEST_SVC_SHA:0:13} ; nothing to do here, if it's up to me I cancel cancel stage"
    cancel_counter=$(echo ${cancel_counter}+1 |bc)
  fi
done

echo ">> Cancel counter reaches '${cancel_counter}/${srv_counter}'"
if [ ${cancel_counter} -eq ${srv_counter} ];then
    /opt/qnib/gocd/common/bin/cancel_stage.sh
else
  echo ">> Supervise RollingUpdate until all services are healthy (not specific to the services updated)"
  go-dockercli superRu --timeout=${SRV_TIMEOUT:-90} --no-print
fi
