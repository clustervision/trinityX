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


display_var TRIX_CTRL_{HOSTNAME,IP}

function error {
    openstack user delete cinder
    openstack service delete cinder
    openstack service delete cinderv2

    for e in $(openstack endpoint list | grep 'volume\|volumev2' | cut -d '|' -f2); do
        openstack endpoint delete $e;
    done

    mysqladmin -uroot -p$MYSQL_ROOT_PASSWORD -f drop cinder || true
    systemctl kill -s SIGKILL openstack-cinder-api.service || true
    systemctl kill -s SIGKILL openstack-cinder-scheduler.service || true
    exit 1
}

trap error ERR

source /root/.admin-openrc

CINDER_PW="$(get_password "$CINDER_PW")"
CINDER_DB_PW="$(get_password "$CINDER_DB_PW")"

echo_info "Setting up a cinder database"

mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO "cinder"@"localhost" \
  IDENTIFIED BY "${CINDER_DB_PW}";
GRANT ALL PRIVILEGES ON cinder.* TO "cinder"@"%" \
  IDENTIFIED BY "${CINDER_DB_PW}";
EOF

echo_info "Creating the cinder service and endpoints"
openstack user create --domain default --password $CINDER_PW cinder
openstack role add --project service --user cinder admin

openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2

openstack endpoint create --region RegionOne volume public http://${TRIX_CTRL_HOSTNAME}:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume internal http://${TRIX_CTRL_HOSTNAME}:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume admin http://${TRIX_CTRL_HOSTNAME}:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 public http://${TRIX_CTRL_HOSTNAME}:8776/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://${TRIX_CTRL_HOSTNAME}:8776/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://${TRIX_CTRL_HOSTNAME}:8776/v2/%\(tenant_id\)s

echo_info "Setting up cinder configuration files"
openstack-config --set /etc/cinder/cinder.conf database connection "mysql+pymysql://cinder:${CINDER_DB_PW}@127.0.0.1/cinder"
openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host ${TRIX_CTRL_HOSTNAME}
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password $OS_RMQ_PW
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://${TRIX_CTRL_HOSTNAME}:5000
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://${TRIX_CTRL_HOSTNAME}:35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken memcached_servers ${TRIX_CTRL_HOSTNAME}:11211
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_type password
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken username cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken password $CINDER_PW
openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip $TRIX_CTRL_IP
openstack-config --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp

openstack-config --set /etc/nova/nova.conf cinder os_region_name RegionOne

echo_info "Initializing the cinder database"
su -s /bin/sh -c "cinder-manage db sync" cinder

echo_info "Starting cinder services and dependencies"
systemctl restart openstack-nova-api.service

systemctl enable openstack-cinder-api.service
systemctl enable openstack-cinder-scheduler.service
systemctl enable target.service

systemctl restart openstack-cinder-api.service
systemctl restart openstack-cinder-scheduler.service
systemctl restart target.service

echo_info "Saving passwords"
store_password CINDER_DB_PW $CINDER_DB_PW
store_password CINDER_PW $CINDER_PW
