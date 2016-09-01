#!/bin/bash

GOCD_SERVER_URL=$(echo ${GO_SERVER_URL} |sed -e 's/https/http/')
export GOCD_SERVER_URL=$(echo ${GOCD_SERVER_URL} |sed -e 's/8154/8153/')
export GOCD_API_URL=$(echo ${GOCD_SERVER_URL}/api |sed -e 's#//api#/api#g')
export GOCD_FILE_URL=$(echo ${GOCD_SERVER_URL}/files |sed -e 's#//files#/files#g')

# Defaults
SRV_MODE=${SRV_MODE:-replicated}

rm -rf target/*.yml target/*.dab

if [ "X${1}" == "Xrollback" ];then
  echo ">> Rollback triggered"
  for dep in $(python -c 'import os; print " ".join([item for item in os.environ if item.startswith("GO_DEPENDENCY_LOCATOR_")])');do
    echo ">>>> unset ${dep}"
    unset ${dep}
  done
  echo ">>> Fetch history: curl -s ${GOCD_API_URL}/pipelines/${GO_PIPELINE_NAME}/history/0"
  LAST_PASSED=$(curl -s ${GOCD_API_URL}/pipelines/${GO_PIPELINE_NAME}/history/0 |jq '.pipelines[] | .label + " " + .stages[].jobs[0].result' |grep Passed |head -1 |awk '{print $1}' |tr -d '"')
  echo ">>> Last passed pipelinerun: ${LAST_PASSED}"
  export GO_DEPENDENCY_LOCATOR_LAST_ROLLBACK=${GO_PIPELINE_NAME}/${LAST_PASSED}/RollingUpdateStage/1
  echo ">>> Overwrite LOCATOR: GO_DEPENDENCY_LOCATOR_LAST_ROLLBACK=${GO_DEPENDENCY_LOCATOR_LAST_ROLLBACK}"
fi

/opt/service-scripts/gocd/common/bin/download-artifacts.sh

COMPOSE_FILE=$(find target -name "docker-compose*.yml")
if [ "X${COMPOSE_FILE}" == "X" ];then
  echo "!! Could not find compose file... exit"
  exit 1
fi
echo ">> COMPOSE_FILE=${COMPOSE_FILE}"
DAB_FILE=$(find target -name "*.dab")
if [ "X${DAB_FILE}" == "X" ];then
  echo "!! Could not find dab file... exit"
  exit 1
fi
echo ">> DAB_FILE=${DAB_FILE}"

cancel_counter=0
srv_counter=$(egrep -c "[a-z\-]+:\s+\#[a-z0-9]+" ${COMPOSE_FILE})
echo "> egrep -o '[a-z\-]+:\s+\#[a-z0-9]+' ${COMPOSE_FILE} |sed -e 's/ /_/g'"
for srv in $(egrep -o "[a-z\-]+:\s+\#[a-z0-9]+" ${COMPOSE_FILE} |sed -e 's/ /_/g');do
  SERVICE_SCALE=$(echo ${srv} |awk -F\:\_\# '{print $2}')
  if [ ${SERVICE_SCALE} == "global" ];then
    SRV_MODE=global
  fi
  SERVICE_NAME=$(echo ${srv} |awk -F\:\_\# '{print $1}')
  ADV_SRV_NAME=${SRV_PREFIX:-qnib}-${SERVICE_NAME}
  echo ">> Looking into Service '${ADV_SRV_NAME}', expected scale '${SERVICE_SCALE}'"
  CUR_SRV_MODE=$(docker service inspect -f '{{json .Spec.Mode }}' ${ADV_SRV_NAME} |jq '. |keys[] |ascii_downcase' |tr -d '"')
  CUR_SVC_IMG=$(docker service ls |grep ${ADV_SRV_NAME} |awk '{print $4}')
  if [ "X${CUR_SVC_IMG}" != "X" ];then
    CUR_SVC_CNT=$(docker service ps --filter desired-state=running ${ADV_SRV_NAME} |grep -c ${ADV_SRV_NAME})
    CUR_SVC_SHA=$(echo ${CUR_SVC_IMG} |awk -F'sha256:' '{print $2}')
    echo ">>>>> Current IMG '$(echo ${CUR_SVC_IMG} |awk -F\: '{print $1}')', current SHA '${CUR_SVC_SHA:0:13}'"
  fi
  LATEST_SVC_IMG=$(jq ".Services.${SERVICE_NAME}.Image" ${DAB_FILE} |tr -d '"')
  SVN_NETS=""
  for SVC_NET in $(jq ".Services.${SERVICE_NAME}.Networks[]" ${DAB_FILE} |tr -d '"' |xargs);do
    if [ $(docker network ls -f name=${SVC_NET} |wc -l) -eq 1 ];then
      echo ">>> Create ${SVC_NET}: docker network create -d overlay ${SVC_NET}"
      docker network create -d overlay ${SVC_NET}
    else
      echo ">>> Network ${SVC_NET} already existing..."
    fi
    SVC_NETS="${SVC_NETS} --network ${SVC_NET}"
  done
  LATEST_SVC_SHA=$(echo ${LATEST_SVC_IMG} |awk -F'sha256:' '{print $2}')
  SVC_PORT=$(jq ".Services.${SERVICE_NAME}.Ports[0].Port" ${DAB_FILE})
  ADV_SVC_PORT=${ADV_SVC_PORT:-${SVC_PORT}}
  echo ">>>>> Dab file wants IMG '$(echo ${LATEST_SVC_IMG}|awk -F\: '{print $1}')' with SHA '${LATEST_SVC_SHA:0:13}' and exposing internal port '${SVC_PORT}'"
  SRV_ENV_CNT="$(jq ".Services.${SERVICE_NAME}.Env[]" ${DAB_FILE} |tr -d '"' |wc -l)"
  if [ ${SRV_ENV_CNT} -ne 0 ];then
    SRV_ENV=""
    for SENV in $(jq ".Services.${SERVICE_NAME}.Env[]" ${DAB_FILE} |tr -d '"' |xargs);do
      if [ $(echo ${SENV} |awk -F\= '{print $1}') == "CONSUL_BOOTSTRAP_EXPECT" ] && [ "X${CONSUL_BOOTSTRAP_EXPECT}" != "X" ];then
        SRV_ENV="${SRV_ENV} CONSUL_BOOTSTRAP_EXPECT=${CONSUL_BOOTSTRAP_EXPECT}"
      else
        SRV_ENV="${SRV_ENV} ${SENV}"
      fi
    done
    SRV_ENV=$(echo ${SRV_ENV} |sed -e 's/ / -e /g' |sed -e 's/^/-e /')
  else
    SRV_ENV=""
  fi
  if [ "X${EXTRA_SRV_ENV}" != "X" ];then
    SRV_ENV=$(echo "${SRV_ENV} -e ${EXTRA_SRV_ENV}")
  fi
  if [ "X${CUR_SVC_IMG}" == "X" ];then
    if [ "X${SEED_SRV}" == "Xtrue" ];then
      echo "XXX No stack running, wramp up the service as a single task to allow bootstraping to happen (set SERVICE_SCALE=1, SRV_MODE=replicated)."
      SERVICE_SCALE=1
      SRV_MODE=replicated
    else
      echo "XXX No stack running, deploy dab file using docker service (as docker deploy is still experimental)"
    fi
    set -e
    if [ ${SRV_MODE} == "global" ];then
      SCALE_OPTS="--mode global"
    else
      SCALE_OPTS="--mode=replicated --replicas=${SERVICE_SCALE}"
    fi
    echo ">>> docker service create --name ${ADV_SRV_NAME} ${SRV_ENV} \ "
    echo "                ${SCALE_OPTS} ${SVC_NETS} \ "
    echo "                --publish ${ADV_SVC_PORT}:${SVC_PORT} \ "
    echo "                --mount type=bind,source=/etc/hostname,target=/etc/docker-hostname:ro \ "
    echo "                ${LATEST_SVC_IMG}"
    set -e
    docker service create --name ${ADV_SRV_NAME} ${SRV_ENV} \
                          ${SCALE_OPTS} ${SVC_NETS} \
                          --publish ${ADV_SVC_PORT}:${SVC_PORT} \
                          --mount type=bind,source=/etc/hostname,target=/etc/docker-hostname:ro \
                          ${LATEST_SVC_IMG}
    set +e
  elif [ ${CUR_SRV_MODE} != ${SRV_MODE} ];then
    echo "XXX Current SRV_MODE ${CUR_SRV_MODE} does not match desired mode ${SRV_MODE}"
    echo "  >> Removing service as updateing mode is not possible [yet]"
    echo ">>> docker service rm ${ADV_SRV_NAME}"
    set -e
    docker service rm ${ADV_SRV_NAME}
    set +e
    echo "  >> (Re)Creating service as updateing mode was not possible [yet]"
    if [ ${SRV_MODE} == "global" ];then
      SCALE_OPTS="--mode global"
    else
      SCALE_OPTS="--mode=replicated --replicas=${SERVICE_SCALE}"
    fi
    echo ">>> docker service create --name ${ADV_SRV_NAME} ${SRV_ENV} \ "
    echo "                ${SCALE_OPTS} ${SVC_NETS} \ "
    echo "                --publish ${ADV_SVC_PORT}:${SVC_PORT} \ "
    echo "                --mount type=bind,source=/etc/hostname,target=/etc/docker-hostname:ro \ "
    echo "                ${LATEST_SVC_IMG}"
    set -e
    docker service create --name ${ADV_SRV_NAME} ${SRV_ENV} \
                          ${SCALE_OPTS} ${SVC_NETS} \
                          --publish ${ADV_SVC_PORT}:${SVC_PORT} \
                          --mount type=bind,source=/etc/hostname,target=/etc/docker-hostname:ro \
                          ${LATEST_SVC_IMG}
    set +e
  elif [ ${CUR_SVC_SHA} != ${LATEST_SVC_SHA} ] || [ "X${DOCKER_FORCE_UPDATE}" == "Xtrue" ];then
    if [ "X${DOCKER_FORCE_UPDATE}" == "Xtrue" ] && [ ${CUR_SVC_SHA} == ${LATEST_SVC_SHA} ];then
       echo "XXX DOCKER_FORCE_UPDATE=${DOCKER_FORCE_UPDATE} ; force update"
    else
       echo "XXX Cur:${CUR_SVC_SHA:0:13} != ${LATEST_SVC_SHA:0:13} ; need to update"
    fi
    if [ ${SRV_MODE} == "global" ];then
      SCALE_OPTS=""
    else
      SCALE_OPTS="--replicas=${SERVICE_SCALE}"
    fi
    echo ">>> docker service update --image=${LATEST_SVC_IMG} ${SCALE_OPTS} \ "
    echo "                --update-parallelism=1 \ "
    echo "                --update-delay=${DOCKER_UPDATE_DELAY:-30s} ${ADV_SRV_NAME}"
    set -e
    docker service update --image=${LATEST_SVC_IMG} ${SCALE_OPTS} \
                          --update-parallelism=1 \
                          --update-delay=${DOCKER_UPDATE_DELAY:-30s} ${ADV_SRV_NAME}
    set +e
  elif [ ${SRV_MODE} != "global" ] && [ ${SERVICE_SCALE} -ne ${CUR_SVC_CNT} ];then
    echo "XXX Service not at the right scale 'Desired:${SERVICE_SCALE} -ne Current:${CUR_SVC_CNT}'"
    set -e
    echo ">>> docker service update --replicas=${SERVICE_SCALE} --update-parallelism=1 \ "
    echo "                          --update-delay=${DOCKER_UPDATE_DELAY:-30s} ${ADV_SRV_NAME}"
    docker service update --replicas=${SERVICE_SCALE} --update-parallelism=1 \
                          --update-delay=${DOCKER_UPDATE_DELAY:-30s} ${ADV_SRV_NAME}
    set +e
  else
    echo "XXX ${CUR_SVC_SHA:0:13} == ${LATEST_SVC_SHA:0:13} ; nothing to do here, if it's up to me I cancel cancel stage"
    cancel_counter=$(echo ${cancel_counter}+1 |bc)
  fi
done

echo ">> Cancel counter reaches '${cancel_counter}/${srv_counter}'"
if [ ${cancel_counter} -eq ${srv_counter} ];then
    /opt/service-scripts/gocd/common/bin/cancel_stage.sh
else
  echo ">> Supervise RollingUpdate until all services are healthy (not specific to the services updated)"
  echo ">>>> go-dockercli superRu --timeout=${SRV_TIMEOUT:-90} --no-print --services ${ADV_SRV_NAME}"
  go-dockercli superRu --timeout=${SRV_TIMEOUT:-90} --no-print --services ${ADV_SRV_NAME}
  EC=$?
  if [ ${EC} -ne 0 ];then
    echo "!!!!! Script detected faulty container (EC:${EC})"
    if [ -x ./target/postdeploy.sh ];then
      ./target/postdeploy.sh
    fi
    exit ${EC}
  else
    echo ">>> go-dockercli returned with errorcode 0, all services are updated and healthy"
  fi
fi
if [ "X${SVC_POST_DELAY}" != "X" ];then
  sleep ${SVC_POST_DELAY}
fi

if [ "X${SRV_PREFIX}" == "Xgreen" ];then
  echo ">> As we are the second wave of this service we should check if '$(echo ${ADV_SRV_NAME} |sed -e 's/green/blue/')' needs to be triggered"
  BLUE_SRV_MODE=$(docker service inspect -f '{{json .Spec.Mode }}' $(echo ${ADV_SRV_NAME} |sed -e 's/green/blue/') |jq '. |keys[] |ascii_downcase' |tr -d '"')
  if [ ${BLUE_SRV_MODE} == 'replicated' ];then
    curl -sX POST -H 'Confirm: true' \
         "${GOCD_API_URL}/pipelines/$(echo ${GO_PIPELINE_NAME} |sed -e 's/green/blue/')/schedule"
  fi
fi

exit 0
