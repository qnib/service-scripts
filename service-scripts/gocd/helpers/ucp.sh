#!/bin/bash
: ${HOME_DIR:="/home"}


function ucp_source_bundle {
  docker info 2>/dev/null |awk '/Name:/{print $2}' > ~/docker-node
  if [[ "X${HOME_DIR}" != "X" ]] && [[ -f "${HOME_DIR}/${UCP_USER}/bundle/env.sh" ]];then
    echo ">> Source bundle '${HOME_DIR}/${UCP_USER}/bundle/env.sh'"
    pushd ${HOME_DIR}/${UCP_USER}/bundle/ >/dev/null
    source env.sh
    docker version
    popd >/dev/null
  else
    echo "[!!] Could not find '${HOME_DIR}/${UCP_USER}/bundle/env.sh'"
  fi
}
