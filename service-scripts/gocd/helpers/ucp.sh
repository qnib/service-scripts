#!/bin/bash

: ${HOME_DIR:="/home"}


function eval_docker_secrets {
  if [[ "X${DOCKER_REGISTRY}" == "X" ]] && [[ -f "/run/secrets/docker/registryname" ]];then
    export DOCKER_REGISTRY=$(cat "/run/secrets/docker/registryname")
  elif [[ "X${DOCKER_REGISTRY}" == "X" ]];then
    export DOCKER_REGISTRY="docker.io"
  fi
  if [[ "X${DOCKER_USER}" == "X" ]] && [[ -f "/run/secrets/docker/${DOCKER_REGISTRY}/username" ]];then
    export DOCKER_USER=$(cat "/run/secrets/docker/${DOCKER_REGISTRY}/username")
  fi
  echo ">> DOCKER_USER:${DOCKER_USER} // DOCKER_REGISTRY=${DOCKER_REGISTRY}"
}

function ucp_source_bundle {
  eval_docker_secrets
  docker info 2>/dev/null |awk '/Name:/{print $2}' > ~/docker-node
  if [[ "X${HOME_DIR}" != "X" ]] && [[ -f "${HOME_DIR}/${DOCKER_USER}/bundle/env.sh" ]];then
    echo ">> Source bundle '${HOME_DIR}/${DOCKER_USER}/bundle/env.sh'"
    pushd ${HOME_DIR}/${DOCKER_USER}/bundle/ >/dev/null
    source env.sh
    docker version
    popd >/dev/null
  else
    echo "[!!] Could not find '${HOME_DIR}/${DOCKER_USER}/bundle/env.sh'"
  fi
}

function docker_login {
  eval_docker_secrets
  if [[ "X${DOCKER_USER}" != "X" ]] && [[ -f "/run/secrets/${DOCKER_REGISTRY}/${DOCKER_USER}/password" ]];then
      docker login ${DOCKER_REGISTRY} --username ${DOCKER_USER} --password $(cat "/run/secrets/${DOCKER_REGISTRY}/${DOCKER_USER}/password")
  else
      echo "[EE] Please provide DOCKER_REGISTRY, DOCKER_USER and mount the password/token to /run/secrets/DOCKER_REGISTRY/DOCKER_USER/password"
  fi
}
