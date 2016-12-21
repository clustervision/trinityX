#!/usr/bin/env bash

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

function do_sql_req {
    if [ -f ~/.my.cnf ]; then
        echo $@ | /usr/bin/mysql
        return 0
    fi
    if [ ${MYSQL_ROOT_PASSWORD} ]; then
        echo $@ | /usr/bin/mysql -u root --password="${MYSQL_ROOT_PASSWORD}"
        return 0
    fi
    echo $@ | /usr/bin/mysql -u root
}

function check_zabbix_installation () {
  echo_info "Check if a previous installation exists"
  local RPM_PKG_MISSING=""
  for package in {zabbix-server-mysql,zabbix-web-mysql,mariadb-server}; do
    if ! yum list -q installed "$package" &>/dev/null; then RPM_PKG_MISSING+=" ${package}"; fi
  done
  if [[ -n "${RPM_PKG_MISSING-unset}" ]]; then
    echo_error "Zabbix does not seem to be installed. Packages missing:${RPM_PKG_MISSING}."
    exit 1
  fi
}

function setup_zabbix_credentials () {
  echo_info $FUNCNAME $@
  ZABBIX_MYSQL_PASSWORD=`get_password $ZABBIX_MYSQL_PASSWORD`
  ZABBIX_ADMIN_PASSWORD=`get_password $ZABBIX_ADMIN_PASSWORD`
  store_password ZABBIX_MYSQL_PASSWORD "${ZABBIX_MYSQL_PASSWORD}"
  store_password ZABBIX_ADMIN_PASSWORD "${ZABBIX_ADMIN_PASSWORD}"
}

function setup_zabbix_database () {
  echo_info "Setup zabbix database"
  if ! systemctl status mariadb &>/dev/null; then
    echo_error "MariaDB seems to not have started: exiting."
  fi
  if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e 'use zabbix' &>/dev/null; then
    echo_warn "Zabbix database detected, you need to erase it to continue."
    if [[ $ZABBIX_DATABASE_OVERWRITE =~ ^([yY][eE][sS]|[yY])$ ]]; then
      mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "drop database zabbix;"
    else
      echo_error "Will not continue: zabbix database present and ZABBIX_DATABASE_OVERWRITE is set to no."
      exit 1
    fi
  fi
  setup_zabbix_credentials
  do_sql_req "CREATE DATABASE ${ZABBIX_MYSQL_DB} CHARACTER SET utf8 COLLATE utf8_bin;"
  do_sql_req "CREATE USER '${ZABBIX_MYSQL_USER}'@'%' IDENTIFIED BY '${ZABBIX_MYSQL_PASSWORD}';"
  do_sql_req "GRANT ALL PRIVILEGES ON ${ZABBIX_MYSQL_DB}.* TO '${ZABBIX_MYSQL_USER}'@'%';"
  zcat "$(rpm -ql zabbix-server-mysql | grep create.sql.gz)" | mysql -uroot zabbix
}

function zabbix_web_config_init () {

  echo_info "Initialize zabbix-web configuration"

  local TIMEZONE=$(readlink /etc/localtime | sed "s/..\/usr\/share\/zoneinfo\///")

  sed -i -e "/php_value date.timezone/c\        php_value date.timezone "${TIMEZONE}""                                       /etc/httpd/conf.d/zabbix.conf

  printf '%b\n' "<?php" \
                "// Zabbix GUI configuration file." \
                "global \$DB\n;" \
                "\$DB['TYPE']     = 'MYSQL';" \
                "\$DB['SERVER']   = '${TRIX_CTRL_IP}';" \
                "\$DB['PORT']     = '0';" \
                "\$DB['DATABASE'] = '"${ZABBIX_MYSQL_DB}"';" \
                "\$DB['USER']     = '"${ZABBIX_MYSQL_USER}"';" \
                "\$DB['PASSWORD'] = '"${ZABBIX_MYSQL_PASSWORD}"';\n" \
                "// Schema name. Used for IBM DB2 and PostgreSQL." \
                "\$DB['SCHEMA'] = '';\n" \
                "\$ZBX_SERVER      = 'localhost';" \
                "\$ZBX_SERVER_PORT = '10051';" \
                "\$ZBX_SERVER_NAME = 'local cluster';\n" \
                "\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;" > /etc/zabbix/web/zabbix.conf.php
}

function edit_zabbix_conf() {


    sed -i -e "/^DBName=/{h;s/=.*/="${ZABBIX_MYSQL_DB}"/};\${x;/^$/{s//DBName=${ZABBIX_MYSQL_DB}/;H};x}"                       /etc/zabbix/zabbix_server.conf
    sed -i -e "/^DBUser=/{h;s/=.*/="${ZABBIX_MYSQL_USER}"/};\${x;/^$/{s//DBUser=${ZABBIX_MYSQL_USER}/;H};x}"                   /etc/zabbix/zabbix_server.conf
    sed -i -e "/^DBPassword=/{h;s/=.*/="${ZABBIX_MYSQL_PASSWORD}"/};\${x;/^$/{s//DBPassword=${ZABBIX_MYSQL_PASSWORD}/;H};x}"   /etc/zabbix/zabbix_server.conf
    append_line /etc/zabbix/zabbix_server.conf SourceIP=${TRIX_CTRL_IP}
    append_line /etc/zabbix/zabbix_server.conf StartPollers=20
    append_line /etc/zabbix/zabbix_server.conf StartIPMIPollers=20
    append_line /etc/zabbix/zabbix_server.conf StartPollersUnreachable=10
    append_line /etc/zabbix/zabbix_server.conf StartPingers=10
    append_line /etc/zabbix/zabbix_server.conf StartSNMPTrapper=1
    append_line /etc/zabbix/zabbix_server.conf CacheSize=1024M
    append_line /etc/zabbix/zabbix_server.conf HistoryCacheSize=1024M
    append_line /etc/zabbix/zabbix_server.conf TrendCacheSize=1024M
    append_line /etc/zabbix/zabbix_server.conf Timeout=30

}

function create_script_dirs() {
    mkdir -p /usr/lib/zabbix/alertscripts
    mkdir -p /usr/lib/zabbix/externalscripts
}

function setup_snmp_trapd () {
  cp -f ${POST_FILEDIR}/snmptrapd.conf /etc/snmp/snmptrapd.conf
  cp -f ${POST_FILEDIR}/snmptt.conf /etc/snmp/snmptt.conf
  cp -f ${POST_FILEDIR}/snmptt.ini /etc/snmp/snmptt.ini
  echo 'OPTIONS="-Lsd -On "' >> /etc/sysconfig/snmptrapd
  mkdir -p /var/log/snmptrap/
  systemctl enable snmptrapd.service
  systemctl start snmptrapd.service
  # how to check:
  # snmptrap -v 1 -c public localhost .1.3.6.1.6.3 "" 0 0 coldStart.0
  # file /var/log/snmptrap/snmptrap.log should be created and filled with some data
}

function copy_data_to_shared() {
    FILES=" /etc/zabbix/zabbix_server.conf \
            /etc/zabbix/web \
            /etc/httpd/conf.d/zabbix.conf
            /usr/lib/zabbix/alertscripts \
            /usr/lib/zabbix/externalscripts \
            "
    for FILE in ${FILES}; do
        if [ ! -e ${TRIX_ROOT}/shared/${FILE} ]; then
            tar -cf - ${FILE} | (cd ${TRIX_ROOT}/shared/; tar -xf -)
        fi
    done
}

function copy_zabbix_scripts() {
  cp -f ${POST_FILEDIR}/zabbix_agentd.d/*   /etc/zabbix/zabbix_agentd.d/
  cp -f ${POST_FILEDIR}/externalscripts/*   /usr/lib/zabbix/externalscripts/
  mkdir -p /var/lib/zabbix/userparameters
  cp -f ${POST_FILEDIR}/userparameters/*    /var/lib/zabbix/userparameters/
  cp -f ${POST_FILEDIR}/sudoers-zabbix      /etc/sudoers.d/zabbix
}

function symlynks_to_config() {
    FILES=" /etc/zabbix/zabbix_server.conf \
            /usr/lib/zabbix/alertscripts \
            /usr/lib/zabbix/externalscripts \
            "
    for FILE in FILES; do
        if [ ! -h ${FILE} ];then
            mv ${FILE}{,.orig}
            ln -s ${TRIX_ROOT}/shared/${FILE} ${FILE}
        fi
    done
}

function slave_copy_files() {
    FILES=" /etc/zabbix/web \
            /etc/httpd/conf.d/zabbix.conf\
            "
    for FILE in ${FILES}; do
        if [ ! -e ${FILE}.orig ];then
            mv ${FILE}{,.orig}
            cp -prf ${TRIX_ROOT}/shared/${FILE} ${FILE}
        fi
    done
}

function zabbix_server_services () {
    if [ "x${1}" = "on" ]; then
        echo_info "Enable and start zabbix service and dependencies"
        systemctl restart zabbix-server
        systemctl restart httpd
        systemctl enable zabbix-server
        systemctl enable httpd
    fi
    if [ "x${1}" = "off" ]; then
        echo_info "Disable and stop zabbix service and dependencies"
        systemctl stop zabbix-server
        systemctl stop httpd
    fi
}

function zabbix_server_config () {
  TOKEN=$(curl -s localhost/zabbix/api_jsonrpc.php \
              -H 'Content-Type: application/json-rpc' \
              -d '{"jsonrpc": "2.0",
                   "method": "user.login",
                   "auth": null,
                   "id": 1,
                   "params": {
                        "user": "Admin",
                        "password": "zabbix"
                   }}' \
         | python -c "import json,sys; auth=json.load(sys.stdin); print(auth['result'])")

  # -------------------------------

  echo_info "Update Admin password"

  curl -s -XPOST localhost/zabbix/api_jsonrpc.php \
       -H 'Content-Type: application/json-rpc' \
       -d "{\"jsonrpc\": \"2.0\",
            \"method\": \"user.update\",
            \"auth\": \"$TOKEN\",
            \"id\": 2,
            \"params\": {
                \"userid\": \"1\",
                \"passwd\": \"$ZABBIX_ADMIN_PASSWORD\"
            }}"

  # -------------------------------

  echo_info "Enable automatic registration of zabbix agents"

  curl -s -XPOST localhost/zabbix/api_jsonrpc.php \
       -H 'Content-Type: application/json-rpc' \
       -d "{\"jsonrpc\": \"2.0\",
            \"method\": \"action.create\",
            \"auth\": \"$TOKEN\",
            \"id\": 3,
            \"params\": {
                \"name\": \"Auto registration\",
                \"eventsource\": 2,
                \"evaltype\": 0,
                \"def_shortdata\": \"Auto registration: {HOST.HOST}\",
                \"def_longdata\": \"Host name: {HOST.HOST}\nHost IP: {HOST.IP}\nAgent port: {HOST.PORT}\",
                \"conditions\": [{\"conditiontype\": 22, \"operator\": 2, \"value\": \"\"}],
                \"operations\": [{\"operationtype\": 2},
                                 {\"operationtype\": 4, \"opgroup\": [{\"groupid\": \"5\"}, {\"groupid\": \"2\"}]},
                                 {\"operationtype\": 6, \"optemplate\": [{\"templateid\": \"10102\"}, {\"templateid\": \"10001\"}, {\"templateid\": \"10104\"}]}]
            }}"

  # -------------------------------

  echo_info "Enable default trigger action: Send notifications"

  curl -s -XPOST localhost/zabbix/api_jsonrpc.php \
       -H 'Content-Type: application/json-rpc' \
       -d "{\"jsonrpc\": \"2.0\",
            \"method\": \"action.update\",
            \"auth\": \"$TOKEN\",
            \"id\": 4,
            \"params\": {
                \"actionid\": \"3\",
                \"status\": \"0\"
            }}"

  # -------------------------------

  echo_info "Add a local email mediatype which zabbix will use to send notifications"

  curl -s -XPOST localhost/zabbix/api_jsonrpc.php \
       -H 'Content-Type: application/json-rpc' \
       -d "{\"jsonrpc\": \"2.0\",
            \"method\": \"mediatype.create\",
            \"auth\": \"$TOKEN\",
            \"id\": 5,
            \"params\": {
                \"description\": \"Local e-mail\",
                \"type\": 0,
                \"smtp_server\": \"localhost\",
                \"smtp_helo\": \"$TRIX_CTRL_HOSTNAME\",
                \"smtp_email\": \"zabbix@$TRIX_CTRL_HOSTNAME\"
            }}"

  # -------------------------------

  echo_info "Setup notifications to be sent to the root user on the controller"

  curl -s -XPOST localhost/zabbix/api_jsonrpc.php \
       -H 'Content-Type: application/json-rpc' \
       -d "{\"jsonrpc\": \"2.0\",
            \"method\": \"user.addmedia\",
            \"auth\": \"$TOKEN\",
            \"id\": 5,
            \"params\": {
                \"users\": [{\"userid\": 1}],
                \"medias\": {\"mediatypeid\": \"4\", \"sendto\": \"root@$TRIX_CTRL_HOSTNAME\", \"active\": 0, \"severity\": 63, \"period\": \"1-7,00:00-24:00\"}
            }}"

    if [ "x${ZABBIX_STORE_HISTORY}" != "x" ]; then
        do_sql_req "UPDATE ${ZABBIX_MYSQL_DB}.config SET hk_history_global=1,hk_history=${ZABBIX_STORE_HISTORY};"
    fi
    if [ "x${ZABBIX_STORE_TRENDS}" != "x" ]; then
        do_sql_req "UPDATE ${ZABBIX_MYSQL_DB}.config SET hk_trends_global=1,hk_trends=${ZABBIX_STORE_TRENDS};"
    fi

}
function configure_pacemaker() {
    echo_info "Configure pacemaker's resources."
    TMPFILE=$(/usr/bin/mktemp -p /root pacemaker_zabbix.XXXX)
    /usr/sbin/pcs cluster cib ${TMPFILE}
    /usr/sbin/pcs -f ${TMPFILE} resource delete zabbix-server || true
    /usr/sbin/pcs -f ${TMPFILE} resource create zabbix-server systemd:zabbix-server --force
    /usr/sbin/pcs -f ${TMPFILE} constraint colocation add zabbix-server with Trinity
    /usr/sbin/pcs -f ${TMPFILE} constraint order start trinity-fs then start zabbix-server
    /usr/sbin/pcs -f ${TMPFILE} constraint order promote Trinity-galera then start zabbix-server
#    /usr/sbin/pcs -f ${TMPFILE} resource group add Trinity zabbix-server --after trinity-ip
    /usr/sbin/pcs cluster cib-push ${TMPFILE}
}

function main () {
    check_zabbix_installation
    create_script_dirs
    setup_snmp_trapd
    zabbix_web_config_init
    if flag_is_unset HA || flag_is_set PRIMARY_INSTALL; then
        setup_zabbix_database
        edit_zabbix_conf
        copy_zabbix_scripts
        copy_data_to_shared

    fi
    symlynks_to_config
    zabbix_server_services on
    if flag_is_unset HA || flag_is_set PRIMARY_INSTALL; then
        zabbix_server_config
    fi
    if flag_is_set HA; then
        zabbix_server_services off
    fi
    if flag_is_set HA && flag_is_set PRIMARY_INSTALL; then
        configure_pacemaker
    fi

}


display_var ZABBIX_{MYSQL_USER,MYSQL_DB,DATABASE_OVERWRITE,STORE_HISTORY,STORE_TRENDS}

echo_info 'Zabbix installation script' && main
