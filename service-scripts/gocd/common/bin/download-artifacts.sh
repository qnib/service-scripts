#!/bin/bash

## Iterate through environment and download artifacts of material into ./target/

GOCD_SERVER_URL=$(echo ${GO_SERVER_URL} |sed -e 's/https/http/')
GOCD_SERVER_URL=$(echo ${GOCD_SERVER_URL} |sed -e 's/8154/8153/')
GOCD_API_URL=$(echo ${GOCD_SERVER_URL}/api |sed -e 's#//api#/api#g')
GOCD_FILE_URL=$(echo ${GOCD_SERVER_URL}/files |sed -e 's#//files#/files#g')

mkdir -p target
for dep in $(python -c 'import os; print " ".join([item for item in os.environ if item.startswith("GO_DEPENDENCY_LOCATOR_")])');do
  LOCATOR_PIPELINE_NAME=$(echo ${!dep} |awk -F/ '{print $1}')
  LOCATOR_PIPELINE_CNT=$(echo ${!dep} |awk -F/ '{print $2}')
  echo ">>>> curl -s ${GOCD_API_URL}/pipelines/${LOCATOR_PIPELINE_NAME}/instance/${LOCATOR_PIPELINE_CNT}"
  JOB_NAME=$(curl -s ${GOCD_API_URL}/pipelines/${LOCATOR_PIPELINE_NAME}/instance/${LOCATOR_PIPELINE_CNT} |jq ".stages[].jobs[0].name" |tr -d '"')
  printf "%s: %-20s\n" ${dep} ${!dep}
  echo ">>>> curl -s ${GOCD_FILE_URL}/${!dep}/${JOB_NAME}.json"
  for item in $(curl -s ${GOCD_FILE_URL}/${!dep}/${JOB_NAME}.json  |jq '..|.url?' |tr -d '"');do
    fname=$(echo ${item} |awk -F/ '{print $NF}')
    echo ">>> Download ${fname}"
    curl -so target/${fname} ${item}
    if [ $(echo ${fname} |egrep -c ".*\.(sh|py)") -ne 0 ];then
      chmod +x target/${fname}
    fi
    if [ $(file target/${fname} |grep -c 'HTML document') -eq 1 ];then
      echo "!!! ${fname} seems to contain HTML content, suspect to be listing of directory, going to remove it"
      rm -f target/${fname}
    fi

  done
done
