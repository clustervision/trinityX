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

function replace_template() {
    [ $# -gt 3 -o $# -lt 2 ] && echo "Wrong numger of argument in replace_template." && exit 1
    if [ $# -eq 3 ]; then
        FROM=${1}
        TO=${2}
        FILE=${3}
    fi
    if [ $# -eq 2 ]; then
        FROM=${1}
        TO=${!FROM}
        FILE=${2}
    fi
    sed -i -e "s/{{ ${FROM} }}/${TO//\//\\/}/g" $FILE
}

function get_partners_ip() {
    if flag_is_unset HA; then
        echo ''
        return
    fi
    if flag_is_set PRIMARY_INSTALL; then
        echo "${TRIX_CTRL2_IP}"
    else
        echo "${TRIX_CTRL1_IP}"
    fi
}

display_var RSYSLOG_CLIENT_NETWORK RSYSLOG_CLIENT_NETWORK_PREFIX RSYSLOG_MESSAGES_PATH

echo_info "Creating $RSYSLOG_MESSAGES_PATH"

mkdir -p $RSYSLOG_MESSAGES_PATH

RSYSLOG_HA_LINE=''
if flag_is_set HA ; then
    echo_info "Running HA."
    RSYSLOG_HA_LINE="*.*   @@$(get_partners_ip):514"
fi

OCTETS=$(( ${RSYSLOG_CLIENT_NETWORK_PREFIX}/8 ))
IPARR=($(echo "${RSYSLOG_CLIENT_NETWORK}" | sed 's/\./ /g'))
NETWORK_START_WITH=$(echo "${IPARR[@]:0:${OCTETS}}" | sed 's/ /\./g')


echo_info "Creating config."

cp ${POST_FILEDIR}/rsyslog.conf /etc/rsyslog.conf

replace_template RSYSLOG_MESSAGES_PATH /etc/rsyslog.conf
replace_template NETWORK_START_WITH /etc/rsyslog.conf
replace_template RSYSLOG_HA_LINE /etc/rsyslog.conf

echo_info "Restart rsyslog."

systemctl restart rsyslog.service
systemctl enable rsyslog.service
