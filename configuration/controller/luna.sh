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

if [ "x${LUNA_MONGO_PASS}" = "x" ]; then
    LUNA_MONGO_PASS=`get_password $LUNA_MONGO_PASS`
    store_password LUNA_MONGO_PASS $LUNA_MONGO_PASS
fi

function install_luna() {
    echo_info "Download Luna"
    pushd /
    [ -d /luna ] || /usr/bin/git clone https://github.com/clustervision/luna
    popd

    echo_info "Add users and create folders."

    /usr/bin/id luna >/dev/null 2>&1 || /usr/sbin/useradd -d /opt/luna luna
    /usr/bin/chown luna: /opt/luna
    /usr/bin/chmod ag+rx /opt/luna
    /usr/bin/mkdir -p /var/log/luna
    /usr/bin/chown luna: /var/log/luna
    /usr/bin/mkdir -p /opt/luna/{boot,torrents}
    /usr/bin/chown luna: /opt/luna/{boot,torrents}

    echo_info "Create symlinks."

    pushd /usr/lib64/python2.7
    /usr/bin/ln -fs ../../../luna/src/module luna
    popd
    pushd /usr/sbin
    /usr/bin/ln -fs ../../luna/src/exec/luna
    /usr/bin/ln -fs ../../luna/src/exec/lpower
    /usr/bin/ln -fs ../../luna/src/exec/lweb
    /usr/bin/ln -fs ../../luna/src/exec/ltorrent
    /usr/bin/ln -fs ../../luna/src/exec/lchroot
    popd
    pushd /opt/luna
    /usr/bin/ln -fs ../../luna/src/templates/
    popd

    echo_info "Copy systemd unit files."

    /usr/bin/cp -pr ${POST_FILEDIR}/lweb.service /etc/systemd/system/lweb.service
    /usr/bin/cp -pr ${POST_FILEDIR}/ltorrent.service /etc/systemd/system/ltorrent.service

    echo_info "Reload systemd config."

    /usr/bin/systemctl daemon-reload
}

function copy_dracut() {
    echo_info "Copy dracut module"

    /usr/bin/mkdir -p ${TRIX_ROOT}/luna/dracut/
    /usr/bin/cp -pr /luna/src/dracut/95luna ${TRIX_ROOT}/luna/dracut/
}

function setup_tftp() {
    echo_info "Setup tftp."

    /usr/bin/mkdir -p /tftpboot
    /usr/bin/sed -e 's/^\(\W\+disable\W\+\=\W\)yes/\1no/g' -i /etc/xinetd.d/tftp
    /usr/bin/sed -e 's|^\(\W\+server_args\W\+\=\W-s\W\)/var/lib/tftpboot|\1/tftpboot|g' -i /etc/xinetd.d/tftp
    [ -f /tftpboot/luna_undionly.kpxe ] || cp /usr/share/ipxe/undionly.kpxe /tftpboot/luna_undionly.kpxe
}

function setup_dns() {
    echo_info "Setup DNS."
    append_line "include \"/etc/named.luna.zones\";" /etc/named.conf
}

function setup_nginx() {
    echo_info "Setup nginx."

    if [ ! -f /etc/nginx/conf.d/nginx-luna.conf ]; then
        # copy config files
        /usr/bin/mv /etc/nginx/nginx.conf{,.bkp_luna}
        /usr/bin/cp ${POST_FILEDIR}/nginx.conf /etc/nginx/
        /usr/bin/mkdir -p /etc/nginx/conf.d/
        /usr/bin/cp ${POST_FILEDIR}/nginx-luna.conf /etc/nginx/conf.d/
    fi
}

function configure_mongo_credentials() {
    echo_info "Configure credentials for MongoDB access."

    /usr/bin/mongo --host luna/localhost -u "root" -p${MONGODB_ROOT_PASS} --authenticationDatabase admin << EOF
use luna
db.createUser({user: "luna", pwd: "${LUNA_MONGO_PASS}", roles: [{role: "dbOwner", db: "luna"}]})
EOF
    /usr/bin/cat > /etc/luna.conf <<EOF
[MongoDB]
server=localhost
authdb=luna
user=luna
password=${LUNA_MONGO_PASS}
EOF
    /usr/bin/chown luna:luna /etc/luna.conf
    /usr/bin/chmod 600 /etc/luna.conf
}

function configure_luna() {
    echo_info "Initialize Luna." 
     
    /usr/sbin/luna cluster init 
    /usr/sbin/luna cluster change --frontend_address ${LUNA_FRONTEND} 
    /usr/sbin/luna network add -n ${LUNA_NETWORK_NAME} -N ${LUNA_NETWORK} -P ${LUNA_PREFIX} 
    /usr/sbin/luna network change -n ${LUNA_NETWORK_NAME} --ns_ip ${LUNA_FRONTEND} --ns_hostname ${CTRL_HOSTNAME}
}

function configure_luna_ha() {
    echo_info "Configure HA in Luna."
    /usr/sbin/luna cluster change --cluster_ips "${CTRL1_IP},${CTRL2_IP}"
}

function configure_dns_dhcp() {
     
    echo_info "Configure DNS and DHCP." 
     
    /usr/sbin/luna cluster makedhcp -N ${LUNA_NETWORK_NAME} -s ${LUNA_DHCP_RANGE_START} -e ${LUNA_DHCP_RANGE_END} --no_ha
    /usr/sbin/luna cluster makedns 
}

function copy_configs_to_shared() {
    /usr/bin/mkdir -p /trinity/shared/etc
    /usr/bin/cp -pr /etc/luna.conf /trinity/shared/etc/
    /usr/bin/cp -pr /etc/named.luna.zones /trinity/shared/etc/
    /usr/bin/mkdir /trinity/shared/etc/xinetd.d
    /usr/bin/cp -pr /etc/xinetd.d/tftp /trinity/shared/etc/xinetd.d/
    /usr/bin/mkdir /trinity/shared/etc/dhcp
    /usr/bin/cp -pr /etc/dhcp/dhcpd.conf /trinity/shared/etc/
    /usr/bin/mkdir -p /trinity/shared/named
    /usr/bin/cp -pr /var/named/*luna* /trinity/shared/named
}
