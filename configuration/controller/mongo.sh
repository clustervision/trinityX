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

if [ "x${MONGODB_ROOT_PASS}" = "x" ]; then
    MONGODB_ROOT_PASS=`get_password $MONGODB_ROOT_PASS`
    store_password MONGODB_ROOT_PASS $MONGODB_ROOT_PASS
fi

function make_bkp() {
    FILE=$1
    SUFFIX="trixbkp.$(/usr/bin/date +%Y-%m-%d_%H-%M-%S)"
    if [ ! -e "${FILE}" ]; then
        echo_warn "Unable to find ${FILE}"
        return 0
    fi
    echo_info "Create backup of $FILE to ${FILE}.${SUFFIX}"
    RES=$(/usr/bin/cp -prf "${FILE}" "${FILE}.${SUFFIX}"; echo $?)
    return $RES

}

function wait_master {
    echo_info "Wait for MongoDB master."
    USER=$1
    PASS=$2
    SEC=$3
    if [ "x${SEC}" = "x" ]; then
        SEC=30
    fi
    ISMASTER="false"

    while [ "x${ISMASTER}" != "xtrue" ]; do
        if [ "x${USER}" = "x" ]; then
            ISMASTER=$(echo "rs.isMaster().ismaster" | /usr/bin/mongo --host luna/localhost | sed -n '/^true$/p')
        else
            ISMASTER=$(echo "rs.isMaster().ismaster" | /usr/bin/mongo --host luna/localhost -u ${USER} -p${PASS} --authenticationDatabase admin | sed -n '/^true$/p')
        fi
        ISMASTER=${ISMASTER:-false}
        echo "${SEC} ISMASTER=${ISMASTER}"
        sleep 1
        SEC=$(( ${SEC}-1 ))
        if [ ${SEC} -le 0 ]; then
            echo_error "Timeout waiting master."
            exit 4
        fi
    done
}

function wait_arbiter() {
    echo_info "Wait for MongoDB arbiter."
    USER=$1
    PASS=$2
    SEC=$3
    if [ "x${SEC}" = "x" ]; then
        SEC=30
    fi
    STATUS="UNKNOWN"

    while [ "x${STATUS}" != "xARBITER" ]; do
        STATUS=$(echo "rs.status().members[1]['stateStr']" | /usr/bin/mongo --host luna/localhost -u ${USER} -p${PASS} --authenticationDatabase admin | sed -n '/^ARBITER$/p')
        STATUS=${STATUS:-UNKNOWN}
        echo "${SEC} STATUS=${STATUS}"
        sleep 1
        SEC=$(( ${SEC}-1 ))
        if [ ${SEC} -le 0 ]; then
            echo_error "Timeout waiting arbiter."
            exit 5
        fi
    done

}

function wait_secondary_sync() {
    echo_info "Wait for syncing MongoDB."
    USER=$1
    PASS=$2
    SEC=$3
    if [ "x${SEC}" = "x" ]; then
        SEC=60
    fi
    STATUS=$(echo "rs.status()" | /usr/bin/mongo -u ${USER} -p${PASS} --authenticationDatabase admin >/dev/null 2>&1; echo $?)

    while [ "x${STATUS}" != "x0" ]; do
        STATUS=${STATUS:-1}
        echo "${SEC} Exit STATUS=${STATUS}"
        sleep 1
        SEC=$(( ${SEC}-1 ))
        if [ ${SEC} -le 0 ]; then
            echo_error "Timeout waiting arbiter."
            exit 5
        fi
        STATUS=$(echo "rs.status()" | /usr/bin/mongo -u ${USER} -p${PASS} --authenticationDatabase admin >/dev/null 2>&1; echo $?)
    done

}

function disable_selinux() {
    echo_info "Disable SELinux."

    sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    setenforce 0
}

function create_mongo_key() {

    echo_info "Create MongoDB key file."

    /usr/bin/openssl rand -base64 741 > /etc/mongo.key
    /usr/bin/chmod 400 /etc/mongo.key
    mkdir -p /trinity/local/etc
    /usr/bin/cp -pr /etc/mongo.key /trinity/local/etc/
    /usr/bin/chown mongodb: /etc/mongo.key
    if [ ! -f /etc/mongo.key ]; then
        echo_err "Unable to create /etc/mongo.key file."
        exit 1
    fi
}

function setup_standalone_mongo() {
    echo_info "MongoDB replica set configuration"
    MONGODB_HOST=$1
    MONGODB_PATH="/var/lib/mongodb"
    if ! make_bkp ${MONGODB_PATH} ; then
        echo_error "Unable to make backup of ${MONGODB_PATH}"
        exit 1
    fi
    rm -rf ${MONGODB_PATH}/*
    if [ ! -f /etc/mongod.conf ]; then
        echo_err "Unable to find /etc/mongod.conf file."
        exit 1
    fi
    /usr/bin/sed -i \
        -e "s/^[#\t ]*bind_ip = .*/bind_ip = 127.0.0.1/" \
        -e "s/^[#\t ]*smallfiles = .*/smallfiles = true/" \
    /etc/mongod.conf

}

function setup_rs_mongo() {
    echo_info "MongoDB replica set configuration"
    MONGODB_HOST=$1
    MONGODB_PATH="/var/lib/mongodb"
    if ! make_bkp ${MONGODB_PATH} ; then
        echo_error "Unable to make backup of ${MONGODB_PATH}"
        exit 1
    fi
    rm -rf ${MONGODB_PATH}/*
    if [ ! -f /etc/mongod.conf ]; then
        echo_err "Unable to find /etc/mongod.conf file."
        exit 1
    fi
    /usr/bin/sed -i \
        -e "s/^[#\t ]*bind_ip = .*/bind_ip = 127.0.0.1,${MONGODB_HOST}/" \
        -e "s/^[#\t ]*keyFile = .*/keyFile = \/etc\/mongo.key/" \
        -e "s/^[#\t ]*replSet = .*/replSet = luna/" \
        -e "s/^[#\t ]*smallfiles = .*/smallfiles = true/" \
    /etc/mongod.conf

}


function copy_mongo_key() {
    echo_info "Copy MongoDB key file."
    if [ ! -f /trinity/local/etc/mongo.key ]; then
        echo_error "Unable to find MongoDB key file in /trinity/local/etc/mongo.key"
        exit 1
    fi
    /usr/bin/cp -pr /trinity/local/etc/mongo.key /etc/
    /usr/bin/chmod 400 /etc/mongo.key
    /usr/bin/chown mongodb: /etc/mongo.key
    if [ ! -f /etc/mongo.key ]; then
        echo_err "Unable to create /etc/mongo.key file."
        exit 1
    fi

}

function setup_rs_mongo() {
    echo_info "MongoDB replica set configuration"
    MONGODB_HOST=$1
    MONGODB_PATH="/var/lib/mongodb"
    if ! make_bkp ${MONGODB_PATH} ; then
        echo_error "Unable to make mackup of ${MONGODB_PATH}"
        exit 1
    fi
    rm -rf ${MONGODB_PATH}/*
    if [ ! -f /etc/mongod.conf ]; then
        echo_err "Unable to find /etc/mongod.conf file."
        exit 1
    fi
    /usr/bin/sed -i \
        -e "s/^[#\t ]*bind_ip = .*/bind_ip = 127.0.0.1,${MONGODB_HOST}/" \
        -e "s/^[#\t ]*keyFile = .*/keyFile = \/etc\/mongo.key/" \
        -e "s/^[#\t ]*replSet = .*/replSet = luna/" \
        -e "s/^[#\t ]*smallfiles = .*/smallfiles = true/" \
    /etc/mongod.conf

}

function initiate_rs() {

    echo_info "Initialize MongoDB replica set."

    STATUS=$(echo "rs.initiate()" |/usr/bin/mongo | /usr/bin/grep -q '"ok" : 1'; echo $?)
    TRY=3
    while [ "x${STATUS}" != "x0" ]; do
        STATUS=${STATUS:-1}
        echo "Try=${TRY} Exit STATUS=${STATUS}"
        sleep 5
        TRY=$(( ${TRY}-1 ))
        if [ ${TRY} -le 0 ]; then
            echo_error "Unable to initiate replica set."
            exit 5
        fi
        STATUS=$(echo "rs.initiate()" |/usr/bin/mongo | /usr/bin/grep -q '"ok" : 1'; echo $?)
    done
    wait_master

}

function mongo_setup_auth() {
    echo_info "Create root user for MongoDB."
    /usr/bin/mongo << EOF
use admin
db.createUser({user: 'root', pwd: '${MONGODB_ROOT_PASS}', roles: [ { role: 'root', db: 'admin' } ]})
EOF

}

function check_rs_status() {
    echo_info "Replica set status."
    /usr/bin/mongo -u root -p${MONGODB_ROOT_PASS} --authenticationDatabase admin <<EOF
rs.status()
EOF
}

function create_auth_file() {
    echo_info "Configure authentication for MongoDB."
    cat > ~/.mongorc.js <<EOF
db.getSiblingDB("admin").auth("root", "${MONGODB_ROOT_PASS}")
EOF
    sed -i -e "s/^[# \t]\+auth.*/auth = true/" /etc/mongod.conf

}

function setup_mongod_arbiter() {
    echo_info "Create MongoDB arbiter."
    MONGODB_FLOATING_HOST=$1
    MONGODB_PATH="/var/lib/mongodb-arbiter"
    if ! make_bkp ${MONGODB_PATH} ; then
        echo_error "Unable to make mackup of ${MONGODB_PATH}"
        exit 1
    fi
    /usr/bin/rm -rf ${MONGODB_PATH}/*
    /usr/bin/rm -rf /root/.mongorc.js
    /usr/bin/cp /etc/mongod.conf /etc/mongod-arbiter.conf
    /usr/bin/sed -i \
        -e "s/^[#\t ]*bind_ip = .*/bind_ip = 127.0.0.1,${MONGODB_FLOATING_HOST}/"  \
        -e "s/^[#\t ]*port = .*/port = 27018/" \
        -e "s/^[#\t ]*pidfilepath = .*/pidfilepath = \/var\/run\/mongodb-arbiter\/mongod.pid/" \
        -e "s/^[#\t ]*logpath = .*/logpath = \/var\/log\/mongodb-arbiter\/mongod-arbiter.log/" \
        -e "s/^[#\t ]*unixSocketPrefix = .*/unixSocketPrefix = \/var\/run\/mongodb-arbiter/" \
        -e "s/^[#\t ]*dbpath = .*/dbpath = \/var\/lib\/mongodb-arbiter/" \
        -e "s/^[#\t ]*nojournal = .*/nojournal = true/" \
        -e "s/^[#\t ]*noprealloc = .*/noprealloc = true/" \
        -e "s/^[#\t ]*smallfiles = .*/smallfiles = true/" \
    /etc/mongod-arbiter.conf

    /usr/bin/cp ${POST_FILEDIR}/mongod-arbiter-sysconfig /etc/sysconfig/mongod-arbiter
    /usr/bin/cp ${POST_FILEDIR}/mongod-arbiter.service /etc/systemd/system/mongod-arbiter.service
    /usr/bin/cp ${POST_FILEDIR}/mongodb-arbiter-logrotate /etc/logrotate.d/mongodb-arbiter

    /usr/bin/systemctl daemon-reload
    for DIR in lib log; do
        /usr/bin/mkdir -p /var/${DIR}/mongodb-arbiter
        /usr/bin/chown mongodb:root /var/${DIR}/mongodb-arbiter
        /usr/bin/chmod 750 /var/${DIR}/mongodb-arbiter
    done

}

function add_arbiter_to_rs() {
    echo_info "Add arbiter to replica set."
    MONGODB_FLOATING_HOST=$1
    STATUS=$(echo "rs.addArb(\"${MONGODB_FLOATING_HOST}:27018\")" | /usr/bin/mongo -u root -p${MONGODB_ROOT_PASS} --authenticationDatabase admin | grep -q '"ok" : 1'; echo $?)
    echo $STATUS
    TRY=10
    while [ "x${STATUS}" != "x0" ]; do
        STATUS=${STATUS:-1}
        echo "Try=${TRY} Exit STATUS=${STATUS}"
        sleep 5
        TRY=$(( ${TRY}-1 ))
        if [ ${TRY} -le 0 ]; then
            echo_error "Timeout waiting arbiter."
            exit 5
        fi
        STATUS=$(echo "rs.addArb(\"${MONGODB_FLOATING_HOST}:27018\")" | /usr/bin/mongo -u root -p${MONGODB_ROOT_PASS} --authenticationDatabase admin | grep -q '"ok" : 1'; echo $?)
    done
}

function add_secondary_to_rs() {
    echo_info "Add arbiter to replica set."
    MONGODB_SLAVE_HOST=$1
    /usr/bin/systemctl start mongod-arbiter.service
    STATUS=$(echo "rs.add(\"${MONGODB_SLAVE_HOST}:27017\")" | /usr/bin/mongo -u root -p${MONGODB_ROOT_PASS} --authenticationDatabase admin | grep -q '"ok" : 1'; echo $?)
    echo $STATUS

}

function configure_pacemaker() {
    echo_info "Configure pacemaker's resources."
    TMPFILE=$(/usr/bin/mktemp -p /root pacemaker_drbd.XXXX)
    /usr/sbin/pcs cluster cib ${TMPFILE}
    /usr/sbin/pcs -f ${TMPFILE} resource delete mongod-arbiter 2>/dev/null || /usr/bin/true
    /usr/sbin/pcs -f ${TMPFILE} resource create mongod-arbiter systemd:mongod-arbiter --force
    /usr/sbin/pcs -f ${TMPFILE} resource update mongod-arbiter op monitor interval=0 # disable fail actions
    /usr/sbin/pcs -f ${TMPFILE} resource group add Luna mongod-arbiter
    /usr/sbin/pcs -f ${TMPFILE} constraint colocation add Luna with Trinity
    /usr/sbin/pcs -f ${TMPFILE} constraint order start trinity-fs then start Luna
    /usr/sbin/pcs cluster cib-push ${TMPFILE}
}

function install_standalone() {
    /usr/bin/systemctl stop mongod
    setup_standalone_mongo ${CTRL1_IP}
    /usr/bin/systemctl restart mongod
    mongo_setup_auth
    create_auth_file
    /usr/bin/systemctl enable mongod
    /usr/bin/systemctl restart mongod
}

function install_primary() {
    /usr/bin/systemctl stop mongod
    create_mongo_key
    setup_rs_mongo ${CTRL1_IP}
    /usr/bin/systemctl restart mongod
    initiate_rs
    wait_master
    mongo_setup_auth
    create_auth_file
    /usr/bin/systemctl enable mongod
    /usr/bin/systemctl restart mongod
    wait_master "root" "${MONGODB_ROOT_PASS}"
    check_rs_status
    setup_mongod_arbiter ${CTRL_IP}
    /usr/bin/systemctl disable mongod-arbiter.service
    /usr/bin/systemctl restart mongod-arbiter.service
    add_arbiter_to_rs ${CTRL_IP}
    wait_arbiter "root" "${MONGODB_ROOT_PASS}"
    add_secondary_to_rs ${CTRL2_IP}
    wait_master "root" "${MONGODB_ROOT_PASS}"
    check_rs_status
    configure_pacemaker
}

function install_secondary() {
    /usr/bin/systemctl stop mongod
    copy_mongo_key
    setup_rs_mongo ${CTRL2_IP}
    setup_mongod_arbiter ${CTRL_IP}
    create_auth_file
    /usr/bin/systemctl enable mongod
    /usr/bin/systemctl restart mongod
    wait_secondary_sync "root" "${MONGODB_ROOT_PASS}"
    check_rs_status
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
