#!/bin/bash
echo ">> Test"
set -e

source /opt/service-scripts/gocd/helpers/gocd-functions.sh
# Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
assemble_build_img_name

if [ "X${SKIP_TEST}" != "Xtrue" ] && [ -d test ];then
    echo ">>>> Run test"
    cd test
    ./run.sh
fi
