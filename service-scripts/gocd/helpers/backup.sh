#!/bin/bash


curl -X POST \
     -H 'Confirm: true' -H 'Accept: application/vnd.go.cd.v1+json' \
     http://${GO_SERVER:-localhost}:8153/go/api/backups 
