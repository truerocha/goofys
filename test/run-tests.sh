#!/bin/bash

#set -o xtrace
set -o errexit
set -o nounset

: ${CLOUD:="s3"}
: ${PROXY_BIN:=""}
: ${PROXY_PID:=""}

function cleanup {
    if [ "$PROXY_PID" != "" ]; then
        kill $PROXY_PID
    fi
}

T=
if [ $# == 1 ]; then
    T="-check.f $1"
fi

trap cleanup EXIT

if [ $CLOUD == "s3" ]; then
    rm -Rf /tmp/s3proxy
    mkdir -p /tmp/s3proxy

    : ${LOG_LEVEL:="warn"}
    export LOG_LEVEL
    PROXY_BIN="java -jar s3proxy.jar --properties test/s3proxy.properties"
elif [ $CLOUD == "azblob" ]; then
    : ${AZURE_STORAGE_ACCOUNT:="devstoreaccount1"}
    : ${AZURE_STORAGE_KEY:="Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="}
    : ${ENDPOINT:="http://127.0.0.1:8080/${AZURE_STORAGE_ACCOUNT}/"}

    if [ ${AZURE_STORAGE_ACCOUNT} == "devstoreaccount1" ]; then
	if ! which azurite >/dev/null; then
	    echo "Azurite missing, run:" >&1
	    echo "npm install -g azurite" >&1
	    exit 1
	fi

	rm -Rf /tmp/azblob
	mkdir -p /tmp/azblob
	PROXY_BIN="azurite-blob -l /tmp/azblob --blobPort 8080 -s"
	#PROXY_BIN="azurite-blob -l /tmp/azblob --blobPort 8080 -d /dev/stdout"
    fi

    export AZURE_STORAGE_ACCOUNT
    export AZURE_STORAGE_KEY
    export ENDPOINT
fi

if [ "$PROXY_BIN" != "" ]; then
    stdbuf -oL -eL $PROXY_BIN &
    PROXY_PID=$!
fi

export CLOUD
go test -timeout 20m -v $(go list ./... | grep -v /vendor/) -check.vv $T
exit $?
