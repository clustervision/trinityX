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
trap report_err ERR

function report_err() {
    echo "ERROR: Unsuccessful backup of the sql database."
}
function guess_zabbix_db_name {
    DBNAME=$(awk -F= '/^DBName=/{print $2}' /etc/zabbix/zabbix_server.conf)
    echo ${DBNAME}
}
function print_help() {
    echo -e "\t[-h]\tThis help"
    echo -e "\t[-f]\tFile to backup to"
    echo -e "\t[-u]\tSQL user"
    echo -e "\t[-p]\tSQL password"
    echo -e "\t[-z]\tDo not backup zabbix's history data"
    echo -e "\t[-d]\tZabbix DB name"

}
# default parameters

ZABBIXDATA=1
ZABBIXDB=$(guess_zabbix_db_name)
CWD=`pwd`
CURDATE=$(date +%Y-%m-%d_%H-%M-%S)
BKPFILE=${CWD}/${CURDATE}-sql.dump.gz
SQLUSER=''
SQLPASSWORD=''

while getopts "hf:u:p:zd:" opt; do
    case  $opt in
        h)
            print_help
            exit 0
            ;;
        f)
            BKPFILE=${OPTARG}
            ;;
        u)
            SQLUSER=${OPTARG}
            ;;
        p)
            SQLPASSWORD=${OPTARG}
            ;;
        z)
            ZABBIXDATA=0
            ;;
        d)
            ZABBIXDB=${OPTARG}
            ;;
        *)
            echo "No such parameter -${OPTARG}"
            print_help
            exit 1
            ;;
    esac
done
# check input paremeters
if [ ${ZABBIXDATA} -eq 0 -a "x${ZABBIXDB}" = "x" ]; then
    echo "ERROR: Unable to determine zabbix DB to exclude history data."
    exit 2
fi

SQLDUMPCMD="mysqldump --single-transaction --flush-logs --hex-blob --master-data=2 -A"

if [ ${ZABBIXDATA} -eq 0 ]; then
    ZCMD=''
    ZABIX_HIST_TABLES="acknowledges alerts auditlog auditlog_details \
        escalations events history history_log history_str history_str_sync \
        history_sync history_text history_uint history_uint_sync trends trends_uint"
    for ZTABLE in ${ZABIX_HIST_TABLES}; do
        ZCMD="${ZCMD} --ignore-table=${ZABBIXDB}.${ZTABLE}"
    done
    SQLDUMPCMD="${SQLDUMPCMD} ${ZCMD}"
fi

if [ "x${SQLUSER}" != "x" ]; then
    SQLDUMPCMD="${SQLDUMPCMD} -u${SQLUSER} -p${SQLPASSWORD}"
fi

${SQLDUMPCMD} | gzip > ${BKPFILE}
echo "INFO: ${BKPFILE}"

