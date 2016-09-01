#!/bin/bash

if [ "X${GOCD_SERVER_URL}" == "X" ];then
    export GOCD_SERVER_URL=http://gocd-server:8153/go
fi

if [ ! -z ${GOCD_CREDENTIALS} ];then
    GOCD_AUTH="-u '${GOCD_CREDENTIALS}'" 
fi
curl -s "${GOCD_SERVER_URL}/api/backups" \
      -H 'Accept: application/vnd.go.cd.v1+json' \
      -H 'Content-Type: application/json' \
      ${GOCD_AUTH} -X POST
