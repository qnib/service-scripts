#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters '$#', please only provide compose file"
    exit 1
fi


# Defaults
SRV_MODE=${SRV_MODE:-replicated}

COMPOSE_FILE=$(find ${1} -name "docker-compose*")
if [ "X${COMPOSE_FILE}" == "X" ];then
  echo "!! Could not find compose file... exit"
  exit 1
fi
COMPOSE_JSON=$(echo ${COMPOSE_FILE} |sed -e 's/yaml/json/')
if [ ${COMPOSE_FILE} == ${COMPOSE_JSON} ];then
    COMPOSE_JSON=$(echo ${COMPOSE_FILE} |sed -e 's/yml/json/')
fi
if [ ${COMPOSE_FILE} == ${COMPOSE_JSON} ];then
    echo "!! yaml and json file are equal... (${COMPOSE_FILE} == ${COMPOSE_JSON})"
    exit 1
fi
echo ">> COMPOSE_FILE=${COMPOSE_FILE}"
python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < ${COMPOSE_FILE} > ${COMPOSE_JSON}
echo ">> COMPOSE_JSON=${COMPOSE_JSON}"
for srv in $(egrep -o "[a-z0-9\-]+:\s+\#[a-z0-9]+" ${COMPOSE_FILE} |sed -e 's/ /_/g');do
  SERVICE_SCALE=$(echo ${srv} |awk -F\:\_\# '{print $2}')
  if [ ${SERVICE_SCALE} == "global" ];then
    SRV_MODE=global
  fi
  SERVICE_NAME=$(echo ${srv} |awk -F\:\_\# '{print $1}')
  if [ "X${SRV_PREFIX}" != "X" ];then
      ADV_SRV_NAME=${SRV_PREFIX}-${SERVICE_NAME}
  else
      ADV_SRV_NAME=${SERVICE_NAME}
  fi
  echo ">> Looking into Service '${ADV_SRV_NAME}', expected scale '${SERVICE_SCALE}'"
  CUR_SRV_MODE=$(docker service inspect -f '{{json .Spec.Mode }}' ${ADV_SRV_NAME} |jq '. |keys[] |ascii_downcase' |tr -d '"')
  CUR_SVC_IMG=$(docker service ls |grep ${ADV_SRV_NAME} |awk '{print $4}')
  if [ "X${CUR_SVC_IMG}" != "X" ];then
    CUR_SVC_CNT=$(docker service ps --filter desired-state=running ${ADV_SRV_NAME} |grep -c ${ADV_SRV_NAME})
    echo ">>>>> Current service count '${CUR_SVC_CNT}'"
  else
    CUR_SVC_CNT=0
  fi
  LATEST_SVC_IMG=$(jq ".services.\"${SERVICE_NAME}\".image" ${COMPOSE_JSON} |tr -d '"')
  if [ "X${CUR_SVC_IMG}" != "X" ] && [ "${LATEST_SVC_IMG}" == ${CUR_SVC_IMG} ];then
      echo ">>>>> Current IMG '${CUR_SVC_IMG}' matches expected one ${LATEST_SVC_IMG}, skipping"
      continue
  fi
  SVN_NETS=""
  for SVC_NET in $(jq ".services.\"${SERVICE_NAME}\".networks | .[]" ${COMPOSE_JSON} |tr -d '"' |xargs);do
    if [ $(docker network ls -f name=${SVC_NET} |wc -l) -eq 1 ];then
      echo ">>> Create ${SVC_NET}: docker network create -d overlay ${SVC_NET}"
      docker network create -d overlay ${SVC_NET}
    else
      echo ">>> Network ${SVC_NET} already existing..."
    fi
    SVC_NETS="${SVC_NETS} --network ${SVC_NET}"
  done
  ## Ports
  SVC_PORTS=""
  for SVC_PORT in $(jq ".services.\"${SERVICE_NAME}\".ports[]" ${COMPOSE_JSON} |tr -d '"' |xargs);do
      SVC_PORTS="${SVC_PORTS} --publish ${SVC_PORT}"
  done
  ## Volumes
  SRV_MNT_CNT="$(jq ".services.\"${SERVICE_NAME}\".volumes[]" ${COMPOSE_JSON} |tr -d '"' |wc -l)"
  if [ ${SRV_MNT_CNT} -ne 0 ];then
    SRV_MNT=""
    for SMNT in $(jq ".services.\"${SERVICE_NAME}\".volumes[]" ${COMPOSE_JSON} |tr -d '"' |xargs);do
        MNT_SRC=$(echo ${SMNT} |awk -F\: '{print $1}')
        MNT_TARGET=$(echo ${SMNT} |awk -F\: '{print $2}')
        if [ "X${MNT_TARGET}" == "X" ];then
            continue
        fi
        MNT_OPT=$(echo ${SMNT} |awk -F\: '{print $3}')
        if [ "X${MNT_OPT}" != "X" ];then
            echo "!! Oha, mount options are not yet implemented here..."
            exit 1
        fi
        SRV_MNT="${SRV_MNT} --mount type=bind,source=${MNT_SRC},target=${MNT_TARGET}"
    done
  fi
  ## Environment
  SRV_ENV_CNT="$(jq ".services.\"${SERVICE_NAME}\".environment[]" ${COMPOSE_JSON} |tr -d '"' |wc -l)"
  if [ ${SRV_ENV_CNT} -ne 0 ];then
    SRV_ENV=""
    for SENV in $(jq ".services.\"${SERVICE_NAME}\".environment[]" ${COMPOSE_JSON} |tr -d '"' |xargs);do
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
  if [ ${SRV_MODE} == "global" ];then
    SCALE_OPTS="--mode global"
  else
    SCALE_OPTS="--mode=replicated --replicas=${SERVICE_SCALE}"
  fi
  if [ ${CUR_SVC_CNT} -eq 0 ];then
      echo "No service running..."
      set -e
      echo ">>> docker service create --name ${ADV_SRV_NAME} ${SRV_ENV} \ "
      echo "                ${SCALE_OPTS} ${SVC_NETS} \ "
      echo "                ${SVC_PORTS} \ "
      echo "                ${SRV_MNT} \ "
      echo "                ${LATEST_SVC_IMG}"
      set -e
      docker service create --name ${ADV_SRV_NAME} ${SRV_ENV} \
                            ${SCALE_OPTS} ${SVC_NETS} \
                            ${SVC_PORTS} \
                            ${SRV_MNT} \
                            ${LATEST_SVC_IMG}
      set +e
  else
    echo ">> Service already running"
    if [ "${LATEST_SVC_IMG}" != ${CUR_SVC_IMG} ];then
        echo ">>>>> Current IMG '${CUR_SVC_IMG}' does not match '${LATEST_SVC_IMG}', update necessary"
        echo ">>> docker service update --image ${LATEST_SVC_IMG} ${ADV_SRV_NAME}"
        #docker service update --image ${LATEST_SVC_IMG} ${ADV_SRV_NAME}
    elif [ ${SRV_MODE} == "replicated" ] && [ ${CUR_SVC_CNT} -ne ${SERVICE_SCALE} ];then
        echo ">>>>> Current scale is not right (${CUR_SVC_CNT} -ne ${SERVICE_SCALE}), update necessary"
        echo ">>> docker service update ${SCALE_OPTS} ${ADV_SRV_NAME}"
        docker service update ${SCALE_OPTS} ${ADV_SRV_NAME}
    fi
  fi

done

rm -f ${COMPOSE_JSON}
