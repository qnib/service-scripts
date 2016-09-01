#!/bin/bash
set -e

if [ "X${GOCD_SERVER_URL}" == "X" ];then
    export GOCD_SERVER_URL=http://gocd-server:8153/go
fi

if [ "X${RC_OK}" != "Xtrue" ];then
    export RC_ATT_COLOR=#cc0000
elif [ "X${RC_OK}" == "Xtrue" ];then
    export RC_ATT_COLOR=#008f00
else
    export RC_ATT_COLOR=#764FA5
fi
export GOCD_JOB_URL=${GOCD_SERVER_URL}/pipelines/${GO_PIPELINE_NAME}/${GO_PIPELINE_COUNTER}/${GO_STAGE_NAME}/${GO_STAGE_COUNTER}
export GOCD_INSTANCE_URL=${GOCD_SERVER_URL}/api/pipelines/${GO_PIPELINE_NAME}/instance/${GO_PIPELINE_COUNTER}
export BUILD_MSG=$(curl -s ${GOCD_INSTANCE_URL} |jq ' .build_cause.material_revisions[].modifications[] | select(.user_name != "Unknown") | .user_name + " > " + .comment' |sed -e 's/"$/\\n"/' |tr -d '"')
export BUILD_TRIGGER=$(curl -s ${GOCD_INSTANCE_URL} |jq ' .build_cause.trigger_message' |tr -d '\"')

if [ $(echo ${BUILD_TRIGGER} |awk '{print $1}') == "modified" ];then
  cat << EOF > /tmp/msg.json
{
    "username": "${GO_PIPELINE_NAME}",
    "icon_url":"${RC_ICON_URL}",
    "text":"$1","attachments":[
        {"title":"${GO_PIPELINE_NAME}: ${BUILD_TRIGGER}",
	 "title_link":"${GOCD_JOB_URL}","text":"${BUILD_MSG}",
	 "image_url":"${RC_ATTACHMENT_IMG}",
	 "color":"${RC_ATT_COLOR}"}
        ]
}
EOF
elif [ $(echo ${BUILD_TRIGGER} |awk '{print $1}') == "triggered" ];then
  cat << EOF > /tmp/msg.json
{
    "username": "${GO_PIPELINE_NAME}",
    "icon_url":"${RC_ICON_URL}",
    "text":"${BUILD_TRIGGER} ${1}","attachments":[]
}
EOF
elif [ $(echo ${BUILD_TRIGGER} |awk '{print $1}') == "Forced" ];then
  cat << EOF > /tmp/msg.json
{
    "username": "${GO_PIPELINE_NAME}",
    "icon_url":"${RC_ICON_URL}",
    "text":"${BUILD_TRIGGER}: ${1}","attachments":[]
}
EOF
else
  cat << EOF > /tmp/msg.json
{
    "username": "${GO_PIPELINE_NAME}",
    "icon_url":"${RC_ICON_URL}",
    "text":"${BUILD_TRIGGER}","attachments":[]
}
EOF

fi


RES=$(curl -sX POST -H "Content-Type: application/json" --data "@/tmp/msg.json" "${RC_SERVER_URL}/hooks/${RC_TOKEN}" |jq ".success")
env > /tmp/env
#rm -f /tmp/msg.json
if [ "X${RES}" == "Xtrue" ];then
    exit 0
else
    exit 1
fi
