#!/bin/bash


function check_gocd_env {
  ENVS="DOCKER_NO_CACHE,DOCKER_FORCE_PULL,DOCKER_REPO,DOCKER_REGISTRY"
  ENVS="${ENVS},GO_PIPELINE_NAME,GO_PIPELINE_COUNTER"
  ENV="${ENVS},UCP_USER"
  for E in $(echo ${ENVS} |sed -e 's/,/ /g');do
    #if [[ -z ${DOCKER_NO_CACHE} ]];then
      echo -n "${E}: "
      read ${E}
      #echo "> Set 'DOCKER_NO_CACHE=${DOCKER_NO_CACHE}'"
    #else
    #  echo "'${DOCKER_NO_CACHE}'"
    #fi
  done
}
