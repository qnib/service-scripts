#!/bin/bash

PNAME=$(echo ${GO_PIPELINE_NAME} |sed -e "s/${GO_ENVIRONMENT_NAME}-//")

cd ${PNAME}
if [[ -x ./predeploy.sh ]];then
    source ./predeploy.sh
fi
/opt/service-scripts/gocd/common/bin/download-artifacts.sh

## Which current images are used?
rm -f temp.env
docker service ls |grep "${PNAME}_" |awk '{print $2" "$5}' | while read l
do
  SVC_NAME=$(echo $l |awk '{print $1}' |cut -d'_' -f 2- |tr '[:lower:]' '[:upper:]')
  IMG_FULL=$(echo $l |awk '{print $2}')
  IMG_NAME=$(echo ${IMG_FULL} |awk -F/ '{print $NF}' |awk -F'\:|@' '{print $1}')
  echo "[DEBUG] ${SVC_NAME} uses currently ${IMG_FULL}"
  if [[ -f ./target/${IMG_NAME}.image_name ]];then
      IMG_FULL=$(cat ./target/${IMG_NAME}.image_name)
      echo "[DEBUG] Found updated image by parent, now ${IMG_FULL}"
  fi
  echo "export ${SVC_NAME}_IMG=${IMG_FULL}" >> temp.env
done
source temp.env
rm -f temp.env

echo "[II] Deploy stack from docker-compose file"
docker stack deploy --compose-file docker-compose.yml ${PNAME}
