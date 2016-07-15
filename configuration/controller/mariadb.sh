#!/bin/bash
set -e

source "$POST_CONFIG"

source /etc/trinity.sh


echo_info "Starting MariaDB server."

systemctl start mariadb

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
