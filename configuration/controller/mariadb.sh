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

echo_info "Starting MariaDB server."

systemctl restart mariadb

function do_sql_req {
    echo $@ | /usr/bin/mysql
}

function pass_esc {
    echo "$1" | sed 's/\(['"'"'\]\)/\\\1/g'
}

function setup_root_pass {
    PASS=`pass_esc $1`
    do_sql_req "UPDATE mysql.user SET Password=PASSWORD('$PASS') WHERE User='root';"
    do_sql_req "FLUSH PRIVILEGES;"
    cat << EOF > ~/.my.cnf
[mysql]
user=root
password=$PASS
[mysqldump]
user=root
password=$PASS
EOF
    chmod 600 ~/.my.cnf

}

function remove_test_db {
    do_sql_req "DROP DATABASE IF EXISTS test;"
    do_sql_req "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
}

function remove_anonymous_users {
        do_sql_req "DELETE FROM mysql.user WHERE User='';"
}

MYSQL_PASS=`get_password $MYSQL_ROOT_PASSWORD`
store_password MYSQL_ROOT_PASSWORD $MYSQL_PASS
setup_root_pass $MYSQL_PASS
remove_test_db
remove_anonymous_users

systemctl enable mariadb
