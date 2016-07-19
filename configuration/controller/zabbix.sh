#!/usr/bin/env bash

source /etc/trinity.sh
source "${TRIX_SHADOW}"
source "${POST_CONFIG}"

function check_zabbix_installation () {
  echo_progress $FUNCNAME $@
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
  echo_progress $FUNCNAME $@
  ZABBIX_MYSQL_PASSWORD=`get_password $ZABBIX_MYSQL_PASSWORD`
  store_password ZABBIX_MYSQL_PASSWORD "${ZABBIX_MYSQL_PASSWORD}"
}

function setup_zabbix_database () {
  echo_progress $FUNCNAME $@
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
  zcat /usr/share/doc/zabbix-server-mysql-3.0.3/create.sql.gz | mysql -uroot zabbix
}

function zabbix_server_config () {
  echo_progress $FUNCNAME $@

  local TIMEZONE=$(readlink /etc/localtime | sed "s/..\/usr\/share\/zoneinfo\///")

  sed -i -e "/^DBHost=/{h;s/=.*/=localhost/};\${x;/^$/{s//DBHost=$(hostname -s)/;H};x}"                                 /etc/zabbix/zabbix_server.conf
  sed -i -e "/^DBName=/{h;s/=.*/="${ZABBIX_MYSQL_DB}"/};\${x;/^$/{s//DBName=${ZABBIX_MYSQL_DB}/;H};x}"                       /etc/zabbix/zabbix_server.conf
  sed -i -e "/^DBUser=/{h;s/=.*/="${ZABBIX_MYSQL_USER}"/};\${x;/^$/{s//DBUser=${ZABBIX_MYSQL_USER}/;H};x}"                   /etc/zabbix/zabbix_server.conf
  sed -i -e "/^DBPassword=/{h;s/=.*/="${ZABBIX_MYSQL_PASSWORD}"/};\${x;/^$/{s//DBPassword=${ZABBIX_MYSQL_PASSWORD}/;H};x}"   /etc/zabbix/zabbix_server.conf
  sed -i -e "/php_value date.timezone/c\        php_value date.timezone "${TIMEZONE}""                                       /etc/httpd/conf.d/zabbix.conf

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

function zabbix_server_services () {
  echo_progress $FUNCNAME $@
  systemctl restart zabbix-server
  systemctl restart httpd
  systemctl enable zabbix-server
  systemctl enable httpd
}

function main () {
  check_zabbix_installation
  setup_zabbix_database
  zabbix_server_config
  zabbix_server_services
}

echo_info 'Zabbix installation script' && main