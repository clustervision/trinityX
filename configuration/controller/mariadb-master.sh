#!/bin/bash
set -e
source "$POST_CONFIG"
source /etc/trinity.sh
source "$TRIX_SHADOW"

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
MASTER_NUM=1
SLAVE_NUM=2

echo_info "Check if remote host is available."

MARIADB_REP_SLAVE_HOSTNAME=`/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} hostname || (echo_error "Unable to connect to ${MARIADB_REP_SLAVE_HOST}"; exit 1)`

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

do_sql_req "CREATE USER '${MARIADB_REP_USER}'@'localhost' IDENTIFIED BY '${MARIADB_REP_PASS}';"
do_sql_req "CREATE USER '${MARIADB_REP_USER}'@'%' IDENTIFIED BY '${MARIADB_REP_PASS}';"
do_sql_req "GRANT REPLICATION SLAVE ON *.* TO '${MARIADB_REP_USER}'@'%';"
do_sql_req "FLUSH PRIVILEGES;"
read LOG_FILE LOG_POS <<<$(do_sql_req "SHOW MASTER STATUS;" | awk 'NF==2{print}')

echo_info "Dump database."


TMPFILE=$(/usr/bin/mktemp -p /root)
/usr/bin/chmod 600 ${TMPFILE}
/usr/bin/mysqldump -u root --password=${MYSQL_ROOT_PASSWORD} -A > ${TMPFILE}
/usr/bin/scp ${TMPFILE} ${MARIADB_REP_SLAVE_HOST}:${TMPFILE}

do_sql_req "UNLOCK TABLES;"

echo_info "Restore dump on other side."

/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/mysql < ${TMPFILE}

echo_info "Copy credential file."

/usr/bin/scp /root/.my.cnf ${MARIADB_REP_SLAVE_HOST}:/root/.my.cnf

echo_info "Restart remote database."

/usr/bin/ssh ${MARIADB_REP_SLAVE_HOST} /usr/bin/systemctl restart mariadb

echo_info "Start replicating."

echo \
    "RESET SLAVE ALL; \
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo \
    "CHANGE MASTER TO MASTER_HOST='${MARIADB_REP_MASTER_HOST}', \
     MASTER_USER='${MARIADB_REP_USER}', \
     MASTER_PASSWORD='${MARIADB_REP_PASS}', \
     MASTER_LOG_FILE='${LOG_FILE}', \
     MASTER_LOG_POS=${LOG_POS};\
    " | /usr/bin/ssh ${MARIADB_REP_SLAVE_HOST}  \
    /usr/bin/mysql -u root --password=${MYSQL_ROOT_PASSWORD}

echo \
    "START SLAVE;; \
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

