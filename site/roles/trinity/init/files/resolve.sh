#!/bin/bash

if [ ! "$(which host)" ]; then
	yum -y install bind-utils 1>&2
fi

if [ ! "$(which host)" ]; then
	echo "Cannot find host and cannot install it" 1>&2
	exit 1
fi

HOST=$1
DNS=$2

RES=$(host -v $HOST|grep -A1 'ANSWER SECTION'|grep PTR|awk '{ print $5 }'|sed -e 's/\.$//')

if [ ! "$RES" ]; then
	RES=$(host $HOST|grep 'domain name pointer'|awk '{ print $5 }'|sed -e 's/\.$//')
fi

if [ ! "$RES" ] && [ "$DNS" ]; then
	RES=$(host -v $HOST $DNS|grep -A1 'ANSWER SECTION'|grep PTR|awk '{ print $5 }'|sed -e 's/\.$//')

	if [ ! "$RES" ]; then
		RES=$(host $HOST $DNS|grep 'domain name pointer'|awk '{ print $5 }'|sed -e 's/\.$//')
	fi
fi

if [ "$RES" ]; then
	echo $RES
	exit
fi

echo "could not resolve $HOST" 1>&2
# yes it should be non-zero exit, but ansible console output will be cluttered
exit

