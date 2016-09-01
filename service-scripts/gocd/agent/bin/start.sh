#!/usr/local/bin/dumb-init /bin/bash

function extend_list {
    python -c "import sys ; first = set(sys.argv[1].split(',')) ; all = first.union(set(sys.argv[2:])) ; print ','.join(all)" $@
}

source /opt/qnib/consul/etc/bash_functions.sh
wait_for_srv gocd-server

if [ "X${GOCD_LOCAL_DOCKERENGINE}" == "Xtrue" ];then
	GOCD_AGENT_AUTOENABLE_RESOURCES=$(extend_list ${GOCD_AGENT_AUTOENABLE_RESOURCES} docker-engine)
fi

consul-template -once -template "/etc/consul-templates/gocd/autoregister.properties.ctmpl:/opt/go-agent/config/autoregister.properties"

/opt/go-agent/agent.sh 2>&1 1>/var/log/gocd-agent.log &
echo $$ > /opt/go-agent/go-agent.pid
tail -f /var/log/gocd-agent.log
