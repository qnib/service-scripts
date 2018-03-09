#!/bin/bash

function ucp_source_bundle {
  if [[ "X${HOME_DIR}" != "X" ]] && [[ -f "${HOME_DIR}/${UCP_USER}/bundle/env.sh" ]];then
    echo ">> Source bundle '${HOME_DIR}/${UCP_USER}/bundle/env.sh'"
    pushd ${HOME_DIR}/${UCP_USER}/bundle/ >/dev/null
    source env.sh
    popd >/dev/null
  fi
}
