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

function create_luna_folders() {
    LPATH=$1
    if [ "x${LPATH}" = "x" ]; then
        LPATH="/opt"
    fi
    echo_info "Add users and create folders."

    if /usr/bin/id -u luna >/dev/null 2>&1; then
        /usr/sbin/userdel luna

    fi
    if grep -q -E "^luna:" /etc/group ; then
        /usr/sbin/groupdel luna
    fi

    /usr/sbin/groupadd -r ${LUNA_GROUP_ID:+"-g $LUNA_GROUP_ID"} luna
    store_variable "${TRIX_SHFILE}" LUNA_GROUP_ID $(/usr/bin/getent group | /usr/bin/awk -F\: '$1=="luna"{print $3}')

    /usr/sbin/useradd -r ${LUNA_USER_ID:+"-u $LUNA_USER_ID"} -g luna -d ${LPATH}/luna luna
    store_variable "${TRIX_SHFILE}" LUNA_USER_ID $(/usr/bin/id -u luna)

    /usr/bin/id luna >/dev/null 2>&1 || /usr/sbin/useradd -d ${LPATH}/luna luna
    /usr/bin/chown -R luna: ${LPATH}/luna
    /usr/bin/chmod ag+rx ${LPATH}/luna
    /usr/bin/mkdir -p /var/log/luna
    /usr/bin/chown -R luna: /var/log/luna
    /usr/bin/mkdir -p /var/run/luna
    /usr/bin/chown -R luna: /var/run/luna
    /usr/bin/mkdir -p ${LPATH}/luna/{boot,torrents}
    /usr/bin/chown -R luna: ${LPATH}/luna/{boot,torrents}
    pushd ${LPATH}/luna
        /usr/bin/ln -fs ../../luna/src/templates/
    popd
}

function install_luna() {
    echo_info "Download Luna"
    pushd /
        [ -d /luna ] && rm -rf /luna
        /usr/bin/git clone https://github.com/clustervision/luna
    popd

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

    echo_info "Copy systemd unit files."

    /usr/bin/cp -pr /luna/src/system/lweb.service /etc/systemd/system/lweb.service
    /usr/bin/cp -pr /luna/src/system/ltorrent.service /etc/systemd/system/ltorrent.service

    echo_info "Reload systemd config."

    /usr/bin/systemctl daemon-reload

    echo_info "Copy autocompletion functions."

    /usr/bin/cp -pr /luna/src/system/luna_autocomplete.sh /etc/profile.d/
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
    /usr/bin/rm -rf /var/named/*luna*
    /usr/bin/rm -rf /etc/named.luna.zones
    /usr/bin/touch /etc/named.luna.zones

    append_line /etc/named.conf "include \"/etc/named.luna.zones\";"
}

function setup_nginx() {
    echo_info "Setup nginx."

    /usr/bin/cp ${POST_FILEDIR}/nginx.conf /etc/nginx/
    /usr/bin/mkdir -p /etc/nginx/conf.d/
    /usr/bin/cp ${POST_FILEDIR}/nginx-luna.conf /etc/nginx/conf.d/
}

function create_mongo_user() {
    echo_info "Configure credentials for MongoDB access."

    /usr/bin/mongo --host luna/localhost -u "root" -p${MONGODB_ROOT_PASS} --authenticationDatabase admin << EOF
use luna
db.createUser({user: "luna", pwd: "${LUNA_MONGO_PASS}", roles: [{role: "dbOwner", db: "luna"}]})
EOF
}

function configure_mongo_credentials() {
    echo_info "Create /etc/luna.conf"
    /usr/bin/cat > /etc/luna.conf <<EOF
[MongoDB]
replicaset=luna
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
    LPATH=$1
    if [ "x${LPATH}" = "x" ]; then
        LPATH="/opt"
    fi
    create_luna_db_backup
    echo -e "use luna\ndb.dropDatabase()" | /usr/bin/mongo -u "root" -p${MONGODB_ROOT_PASS} --authenticationDatabase admin --host luna/localhost
    if ! /usr/sbin/luna cluster init; then
        echo_error "Luna is unale to initialize cluster"
        exit 1
    fi
    /usr/sbin/luna cluster change --path "${LPATH}/luna"
    /usr/sbin/luna cluster change --frontend_address ${LUNA_FRONTEND}
    /usr/sbin/luna network add -n ${LUNA_NETWORK_NAME} -N ${LUNA_NETWORK} -P ${LUNA_PREFIX}
    /usr/sbin/luna network change -n ${LUNA_NETWORK_NAME} --ns_ip ${LUNA_FRONTEND} --ns_hostname ${CTRL_HOSTNAME}
}

function create_luna_db_backup() {
    SUFFIX="trixbkp.$(/usr/bin/date +%Y-%m-%d_%H-%M-%S)"
    BKPPATH=/root/mongo.luna.${SUFFIX}
    echo_info "Create Luna DB backup to ${BKPPATH}."
    /usr/bin/mongodump -u "root" -p${MONGODB_ROOT_PASS} --authenticationDatabase admin --host luna/localhost -d luna -o ${BKPPATH}

}

function configure_dns_dhcp() {

    echo_info "Configure DNS and DHCP."

    if ! /usr/sbin/luna cluster makedhcp -N ${LUNA_NETWORK_NAME} -s ${LUNA_DHCP_RANGE_START} -e ${LUNA_DHCP_RANGE_END}; then
        echo_error "Luna is unable to create dhcpd config."
        exit 1
    fi
    if ! /usr/sbin/luna cluster makedns; then
        echo_error "Luna is unable to create DNS config."
        exit 1
    fi
}

function copy_configs_to_trix_local() {
    /usr/bin/mkdir -p /trinity/local/etc
    /usr/bin/mv /etc/named.luna.zones /trinity/local/etc/

    /usr/bin/mkdir -p /trinity/shared/etc/dhcp
    /usr/bin/mv /etc/dhcp/dhcpd.conf /trinity/shared/etc/

    /usr/bin/mkdir -p /trinity/local/var
    /usr/bin/mv /var/named /trinity/local/var/
}

function create_symlinks() {
    /usr/bin/ln -fs /trinity/local/etc/named.luna.zones /etc/named.luna.zones
    /usr/bin/ln -fs /trinity/shared/etc/dhcpd.conf /etc/dhcp/dhcpd.conf
    /usr/bin/ln -fs /trinity/local/var/named /var/named
}
function configure_pacemaker() {
        echo_info "Configure pacemaker's resources."
}

function install_standalone() {
    /usr/bin/systemctl stop named dhcpd xinetd nginx
    /usr/bin/systemctl stop lweb ltorrent 2>/dev/null || true
    install_luna
    create_luna_folders
    copy_dracut
    setup_tftp
    setup_dns
    setup_nginx
    create_mongo_user
    configure_mongo_credentials
    configure_luna
    if ! /usr/bin/systemctl start lweb ltorrent; then
        echo_error "Unable to start Luna services."
        exit 1
    fi
    if ! /usr/bin/systemctl start named dhcpd xinetd nginx; then
        echo_error "Unable to start services."
        exit 1
    fi
    /usr/bin/systemctl enable named dhcpd xinetd nginx lweb ltorrent
}

function install_primary() {
    install_standalone
    /usr/bin/systemctl disable named dhcpd xinetd nginx lweb ltorrent
    /usr/bin/systemctl stop named dhcpd xinetd nginx lweb ltorrent
    copy_configs_to_trix_local
    create_symlinks
    configure_pacemaker
}

function install_secondary() {
    /usr/bin/systemctl stop named dhcpd xinetd nginx
    /usr/bin/systemctl stop lweb ltorrent 2>/dev/null || true
    install_luna
    create_luna_folders
    setup_tftp
    setup_dns
    setup_nginx
    configure_mongo_credentials
    /usr/bin/systemctl disable named dhcpd xinetd nginx lweb ltorrent
    #/usr/bin/systemctl restart named dhcpd xinetd nginx lweb ltorrent
    create_symlinks
}

if flag_is_unset HA; then
    install_standalone
else
    if flag_is_set PRIMARY_INSTALL; then
        install_primary
    else
        install_secondary
    fi
fi

