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
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "create database zabbix character set utf8 collate utf8_bin;"
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "grant all privileges on zabbix.* to zabbix@localhost identified by '$ZABBIX_MYSQL_PASSWORD';"
  zcat "$(rpm -ql zabbix-server-mysql | grep create.sql.gz)" | mysql -uroot zabbix
}

function zabbix_server_config_init () {
  echo_info "Initialize zabbix configuration"

  local TIMEZONE=$(readlink /etc/localtime | sed "s/..\/usr\/share\/zoneinfo\///")

  sed -i -e "/^DBName=/{h;s/=.*/="${ZABBIX_MYSQL_DB}"/};\${x;/^$/{s//DBName=${ZABBIX_MYSQL_DB}/;H};x}"                       /etc/zabbix/zabbix_server.conf
  sed -i -e "/^DBUser=/{h;s/=.*/="${ZABBIX_MYSQL_USER}"/};\${x;/^$/{s//DBUser=${ZABBIX_MYSQL_USER}/;H};x}"                   /etc/zabbix/zabbix_server.conf
  sed -i -e "/^DBPassword=/{h;s/=.*/="${ZABBIX_MYSQL_PASSWORD}"/};\${x;/^$/{s//DBPassword=${ZABBIX_MYSQL_PASSWORD}/;H};x}"   /etc/zabbix/zabbix_server.conf
  sed -i -e "/php_value date.timezone/c\        php_value date.timezone "${TIMEZONE}""                                       /etc/httpd/conf.d/zabbix.conf

cat >> /etc/zabbix/zabbix_server.conf <<EOF
SourceIP=${TRIX_CTRL_IP}
StartPollers=20
StartIPMIPollers=20
StartPollersUnreachable=10
StartPingers=10
StartSNMPTrapper=1
CacheSize=1024M
HistoryCacheSize=1024M
TrendCacheSize=1024M
Timeout=30
EOF

  printf '%b\n' "<?php" \
                "// Zabbix GUI configuration file." \
                "global \$DB\n;" \
                "\$DB['TYPE']     = 'MYSQL';" \
                "\$DB['SERVER']   = 'localhost';" \
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

function copy_zabbix_scripts () {
  cp -f ${POST_FILEDIR}/zabbix_agentd.d/*   /etc/zabbix/zabbix_agentd.d/
  cp -f ${POST_FILEDIR}/externalscripts/*   /usr/lib/zabbix/externalscripts/
  mkdir -p /var/lib/zabbix/userparameters
  cp -f ${POST_FILEDIR}/userparameters/*    /var/lib/zabbix/userparameters/
  cp -f ${POST_FILEDIR}/sudoers-zabbix      /etc/sudoers.d/zabbix
}

function zabbix_server_services () {
  echo_info "Enable and start zabbix service and dependencies"
  systemctl restart zabbix-server
  systemctl restart httpd
  systemctl enable zabbix-server
  systemctl enable httpd
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
                \"smtp_server\": \"$TRIX_CTRL_HOSTNAME\",
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

}

function main () {
  check_zabbix_installation
  setup_zabbix_database
  zabbix_server_config_init
  zabbix_server_services
  zabbix_server_config
}

echo_info 'Zabbix installation script' && main
