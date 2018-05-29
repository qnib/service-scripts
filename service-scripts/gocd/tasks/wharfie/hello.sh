#!/bin/bash

#####
# WHARFIE_DEBUG=false ./job.sh ubuntu-openmpi:latest-rev4
set -e

: ${FROM_IMG_REGISTRY:=docker.io}
: ${FROM_IMG_REPO:=qspack}
: ${FROM_IMG_NAME:=debian-openmpi}
: ${FROM_IMG_TAG:=latest}
: ${SLURM_JOB_ID:=1}
: ${WHARFIE_HOMEDIR:=/home}
: ${WHARFIE_VOLUMES:=/efs:/home}
: ${WHARFIE_DEBUG:=false}
: ${WHARFIE_CONSTRAINTS:=node.labels.system==3F1EE8}


source /opt/service-scripts/gocd/helpers/ucp.sh
ucp_source_bundle
source /opt/service-scripts/gocd/helpers/gocd-functions.sh
query_parent

set -x
export FROM_IMG_NAME=$(echo ${FROM_IMG_NAME} |cut -d'.' -f 1)
WHARFIE_DOCKER_IMAGE=${FROM_IMG_REGISTRY}/${FROM_IMG_REPO}/${FROM_IMG_NAME}:${FROM_IMG_TAG}

go-wharfie --bundle --job-id=${GO_PIPELINE_COUNTER} stage \
           --volumes=${WHARFIE_VOLUMES} \
           --username=cluser --user=1000:1000 \
           --homedir=${WHARFIE_HOMEDIR} \
           --docker-image=${WHARFIE_DOCKER_IMAGE}
docker ps -f "label=com.docker.swarm.service.name=jobid${GO_PIPELINE_COUNTER}"
CNT_ID=$(docker ps -qlf "label=com.docker.swarm.service.name=jobid${GO_PIPELINE_COUNTER}" |head -n1)
docker exec -e SLURM_JOB_ID=${GO_PIPELINE_COUNTER} -e WHARFIE_DEBUG=${WHARFIE_DEBUG} \
           --tty -u cluser ${CNT_ID} bash /home/cluser/mpirun.sh
docker service rm jobid${GO_PIPELINE_COUNTER}
