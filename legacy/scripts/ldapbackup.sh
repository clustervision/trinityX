#!/bin/bash

######################################################################
# TrinityX
# Copyright (c) 2016  ClusterVision B.V.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License (included with the sources) for more
# details.
######################################################################

set -e
trap cleanup EXIT
trap report_err ERR

function cleanup() {
    cd ${CWD}
    if [ ${TMPDIR} ]; then
        rm -rf ${TMPDIR}
    fi
}
function report_err() {
    echo "ERROR: Unsuccessful backup of the ldap database."
}
TMPDIR=$(mktemp -d)
CWD=`pwd`
CURDATE=$(date +%Y-%m-%d_%H-%M-%S)
pushd $TMPDIR > /dev/null
BKPDIR=${CURDATE}-ldap-bkp
mkdir ${BKPDIR}
pushd ${BKPDIR} > /dev/null
slapcat -b cn=config | \
    awk -F\= '/^dn: olcDatabase=/{gsub("{|}|,"," ", $2);print $2}' | \
        while read INDEX r; do
            if [ ${INDEX} -ge 0 ]; then
                echo "INFO: Backup DB index ${INDEX}"
                slapcat -n ${INDEX} -l ldap-olcdatabase-${INDEX}.bkp.ldif || \
                    echo "ERROR: Slapcat for DB index ${INDEX}"
                if [ $ERR ]; then
                    echo "ERROR: Slapcat for DB index ${INDEX}"
                fi
            fi
        done
popd  > /dev/null
tar -czf ${CWD}/${BKPDIR}.tgz ${BKPDIR}
popd > /dev/null
echo "INFO: ${CWD}/${BKPDIR}.tgz"

