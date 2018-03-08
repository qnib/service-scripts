#!/bin/bash

function ucp_source_bundle {
  if [[ "X${HOME_DIR}" != "X" ]] && [[ -f "${HOME_DIR}/${UCP_USER}/env.sh" ]];then
    echo ">> Source bundle '${HOME_DIR}/${UCP_USER}/env.sh'"
    pushd ${HOME_DIR}/${UCP_USER}/ >/dev/null
    source env.sh
    popd >/dev/null
  fi
}
