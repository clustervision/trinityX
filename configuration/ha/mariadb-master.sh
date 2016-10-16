#!/bin/bash

######################################################################
# Trinity X
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

function do_sql_req {
    if [ -f ~/.my.cnf ]; then
        echo "$@" | /usr/bin/mysql
        return 0
    fi
    if [ ${MYSQL_ROOT_PASSWORD} ]; then
        echo "$@" | /usr/bin/mysql -u root --password="${MYSQL_ROOT_PASSWORD}"
        return 0
    fi
    echo "$@" | /usr/bin/mysql -u root
}

function replace_template {
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

echo_info "Check if variables are defined."

echo "MARIADB_REP_USER=${MARIADB_REP_USER:?"Should be defined"}"
echo "MARIADB_REP_MASTER_HOST=${MARIADB_REP_MASTER_HOST:?"Should be defined"}"
echo "MARIADB_REP_SLAVE_HOST=${MARIADB_REP_SLAVE_HOST:?"Should be defined"}"
if [ ! "${MARIADB_REP_PASS}" ]; then
    MARIADB_REP_PASS=`get_password $MARIADB_REP_PASS`
    store_password MARIADB_REP_PASS ${MARIADB_REP_PASS}
fi
echo "PACEMAKER_MONITOR_USER=${PACEMAKER_MONITOR_USER:?"Should be defined"}"
if [ ! "${PACEMAKER_MONITOR_USER_PASS}" ]; then
    PACEMAKER_MONITOR_USER_PASS=`get_password $PACEMAKER_MONITOR_USER_PASS`
    store_password PACEMAKER_MONITOR_USER_PASS ${PACEMAKER_MONITOR_USER_PASS}
fi

MASTER_NUM=1
SLAVE_NUM=2

MARIADB_REP_MASTER_HOSTNAME=$(/usr/bin/hostname -s )

echo_info "Check if remote host is available."

MARIADB_REP_SLAVE_HOSTNAME=`/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/hostname -s || (echo_error "Unable to connect to ${MARIADB_REP_SLAVE_HOST}"; exit 1)`

echo_info "Create config file."

[ -f /etc/my.cnf.d/trinity_replication.cnf ] && ( echo_error "MariaDB config /etc/my.cnf.d/trinity_replication.cnf exists! Stopping!"; exit 1 )

/usr/bin/cp ${POST_FILEDIR}/trinity_replication.cnf /etc/my.cnf.d/trinity_replication.cnf
/usr/bin/cp ${POST_FILEDIR}/trinity_replication.cnf /etc/my.cnf.d/trinity_replication_slave.cnf


replace_template NUM ${MASTER_NUM} /etc/my.cnf.d/trinity_replication.cnf
replace_template NUM ${SLAVE_NUM} /etc/my.cnf.d/trinity_replication_slave.cnf

/usr/bin/scp /etc/my.cnf.d/trinity_replication_slave.cnf ${MARIADB_REP_SLAVE_HOST}:/etc/my.cnf.d/trinity_replication.cnf
/usr/bin/rm /etc/my.cnf.d/trinity_replication_slave.cnf

echo_info "Restart local batabase"

/usr/bin/systemctl restart mariadb

echo_info "Create replication user."

do_sql_req "DROP USER '${MARIADB_REP_USER}'@'localhost';" || true
do_sql_req "FLUSH PRIVILEGES;"
do_sql_req "CREATE USER '${MARIADB_REP_USER}'@'localhost' IDENTIFIED BY '${MARIADB_REP_PASS}';"
do_sql_req "FLUSH PRIVILEGES;"
do_sql_req "DROP USER '${MARIADB_REP_USER}'@'%';"  || true
do_sql_req "FLUSH PRIVILEGES;"
do_sql_req "CREATE USER '${MARIADB_REP_USER}'@'%' IDENTIFIED BY '${MARIADB_REP_PASS}';"
do_sql_req "GRANT SUPER, REPLICATION SLAVE, REPLICATION CLIENT, PROCESS, RELOAD ON *.* TO '${MARIADB_REP_USER}'@'%';"
do_sql_req "GRANT SUPER, REPLICATION SLAVE, REPLICATION CLIENT, PROCESS, RELOAD ON *.* TO '${MARIADB_REP_USER}'@'localhost';"
do_sql_req "FLUSH PRIVILEGES;"

echo_info "Create user for pacemaker healthcheck."

do_sql_req "DROP USER '${PACEMAKER_MONITOR_USER}'@'localhost';" || true
do_sql_req "FLUSH PRIVILEGES;"
do_sql_req "CREATE USER '${PACEMAKER_MONITOR_USER}'@'localhost' IDENTIFIED BY '${PACEMAKER_MONITOR_USER_PASS}';"
do_sql_req "FLUSH PRIVILEGES;"
do_sql_req "DROP USER '${PACEMAKER_MONITOR_USER}'@'%';"  || true
do_sql_req "FLUSH PRIVILEGES;"
do_sql_req "CREATE USER '${PACEMAKER_MONITOR_USER}'@'%' IDENTIFIED BY '${PACEMAKER_MONITOR_USER_PASS}';"
do_sql_req "FLUSH PRIVILEGES;"
do_sql_req "CREATE DATABASE IF NOT EXISTS ${PACEMAKER_MONITOR_DB};"
do_sql_req "GRANT ALL PRIVILEGES ON ${PACEMAKER_MONITOR_DB}.* TO '${PACEMAKER_MONITOR_USER}'@'%';"
do_sql_req "GRANT ALL PRIVILEGES ON ${PACEMAKER_MONITOR_DB}.* TO '${PACEMAKER_MONITOR_USER}'@'localhost';"
do_sql_req "CREATE TABLE pacemaker.test (test int);" || true
do_sql_req "FLUSH PRIVILEGES;"

echo_info "Read current master status"

read LOG_FILE LOG_POS <<<$(do_sql_req "SHOW MASTER STATUS;" | awk 'NF==2{print}')

echo_info "Dump database."

TMPFILE=$(/usr/bin/mktemp -p /root sqldump.XXXXXXXXX)
/usr/bin/chmod 600 ${TMPFILE}
/usr/bin/mysqldump -u root --password=${MYSQL_ROOT_PASSWORD} -A > ${TMPFILE}
/usr/bin/scp -p ${TMPFILE} ${MARIADB_REP_SLAVE_HOST}:${TMPFILE}

do_sql_req "UNLOCK TABLES;"

echo_info "Start remote MariaDB server"

/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/systemctl start mariadb

echo_info "Restore dump on slave."

/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/mysql < ${TMPFILE}

echo_info "Copy credential file."

/usr/bin/scp -p /root/.my.cnf ${MARIADB_REP_SLAVE_HOST}:/root/.my.cnf

echo_info "Restart remote database."

/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/systemctl restart mariadb

echo_info "Start replicating."

echo \
    "STOP SLAVE; \
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD} || true

echo \
    "RESET SLAVE ALL; \
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo \
    "CHANGE MASTER TO MASTER_HOST='${MARIADB_REP_MASTER_HOSTNAME}', \
     MASTER_USER='${MARIADB_REP_USER}', \
     MASTER_PASSWORD='${MARIADB_REP_PASS}', \
     MASTER_LOG_FILE='${LOG_FILE}', \
     MASTER_LOG_POS=${LOG_POS};\
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo \
    "START SLAVE; \
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo_info "Test replication."

TMPNAME=$(mktemp -u -t tmpXXXXXXXXXX -p .)
do_sql_req "CREATE DATABASE ${TMPNAME#*/};"
/usr/bin/sleep 1
/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} echo "USE ${TMPNAME#*/};" | \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo_info "Success!"

do_sql_req "DROP DATABASE ${TMPNAME#*/};"

echo_info "Show master status."

do_sql_req "SHOW MASTER STATUS\G"

echo_info "Show slave status."

echo \
    "SHOW SLAVE STATUS\G \
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo_info "Stop replication."

echo \
    "STOP SLAVE; \
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}
echo \
    "RESET SLAVE ALL; \
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo_info "Disable systemd services."

/usr/bin/systemctl stop mariadb
/usr/bin/systemctl disable mariadb
/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/systemctl stop mariadb
/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/systemctl disable mariadb

echo_info "Copy agent."

/usr/bin/mkdir -p /usr/lib/ocf/resource.d/percona
/usr/bin/cp ${POST_FILEDIR}/mysql_prm_agent /usr/lib/ocf/resource.d/percona/mysql
chmod 755 /usr/lib/ocf/resource.d/percona/mysql
/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/mkdir -p /usr/lib/ocf/resource.d/percona
/usr/bin/scp ${POST_FILEDIR}/mysql_prm_agent ${MARIADB_REP_SLAVE_HOST}:/usr/lib/ocf/resource.d/percona/mysql
/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} chmod 755 /usr/lib/ocf/resource.d/percona/mysql

echo_info "Add pacemaker config."

TMPFILE=$(/usr/bin/mktemp -p /root pacemaker.XXXXXXXXX)
/usr/bin/chmod 600 ${TMPFILE}
/usr/sbin/pcs cluster cib ${TMPFILE}

/usr/sbin/pcs -f ${TMPFILE} resource create MariaDB ocf:percona:mysql \
    binary=/usr/libexec/mysqld \
    client_binary=/usr/bin/mysql \
    config=/etc/my.cnf \
    datadir=/var/lib/mysql \
    user=mysql group=mysql \
    log=/var/log/mariadb/mariadb.log \
    pid=/var/run/mariadb/mariadb.pid \
    socket=/var/lib/mysql/mysql.sock \
    test_table=${PACEMAKER_MONITOR_DB}.test \
    test_user=${PACEMAKER_MONITOR_USER} \
    test_passwd=${PACEMAKER_MONITOR_USER_PASS} \
    enable_creation=true \
    replication_user=${MARIADB_REP_USER} \
    replication_passwd=${MARIADB_REP_PASS} \
    max_slave_lag=60 \
    evict_outdated_slaves="false"
/usr/sbin/pcs -f ${TMPFILE} resource update MariaDB op add start interval="0" timeout="60s"
/usr/sbin/pcs -f ${TMPFILE} resource update MariaDB op add stop  interval="0" timeout="60s"
/usr/sbin/pcs -f ${TMPFILE} resource master MariaDB
/usr/sbin/pcs -f ${TMPFILE} resource meta MariaDB-master \
    master-max="1" \
    master-node-max="1" \
    clone-max="2" \
    clone-node-max="1" \
    notify="true" \
    globally-unique="false" \
    target-role="Master" \
    is-managed="true"

/usr/sbin/pcs -f ${TMPFILE} resource op add MariaDB monitor interval="15s" role="Master" OCF_CHECK_LEVEL="1"
/usr/sbin/pcs -f ${TMPFILE} resource op add MariaDB monitor interval="25s" role="Slave" OCF_CHECK_LEVEL="1"

/usr/sbin/pcs -f ${TMPFILE} constraint colocation add master MariaDB-master with ClusterIP

/usr/sbin/pcs cluster cib-push ${TMPFILE}
