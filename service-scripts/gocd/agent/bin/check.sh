#!/bin/bash

echoerr() { echo "$@" 1>&2; }

if [ -f /opt/go-agent/go-agent.pid ];then
    kill -s 0 $(cat /opt/go-agent/go-agent.pid)
    if [ $? -eq 0 ];then
        echo "gocd-agent process is running"
        exit 0
    else
        echoerr "gocd-agent terminated"
        exit 1
    fi
else
   echoerr "no pid-file, gocd-agent startscript has not yet started?"
   exit 1 
fi
