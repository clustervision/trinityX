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
    openstack user delete nova
    openstack service delete nova

    for e in $(openstack endpoint list | grep compute | cut -d '|' -f2); do
        openstack endpoint delete $e;
    done

    mysqladmin -uroot -p$MYSQL_ROOT_PASSWORD -f drop nova || true
    mysqladmin -uroot -p$MYSQL_ROOT_PASSWORD -f drop nova_api || true
    systemctl kill -s SIGKILL openstack-nova-api.service || true
    systemctl kill -s SIGKILL openstack-nova-consoleauth.service || true
    systemctl kill -s SIGKILL openstack-nova-scheduler.service || true
    systemctl kill -s SIGKILL openstack-nova-conductor.service || true
    systemctl kill -s SIGKILL openstack-nova-novncproxy.service || true
    exit 1
}

trap error ERR

source /root/.admin-openrc

NOVA_PW="$(get_password "$NOVA_PW")"
NOVA_DB_PW="$(get_password "$NOVA_DB_PW")"

echo_info "Setting up the nova database"

mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE nova_api;
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova_api.* TO "nova"@"localhost" \
  IDENTIFIED BY "${NOVA_DB_PW}";
GRANT ALL PRIVILEGES ON nova_api.* TO "nova"@"%" \
  IDENTIFIED BY "${NOVA_DB_PW}";
GRANT ALL PRIVILEGES ON nova.* TO "nova"@"localhost" \
  IDENTIFIED BY "${NOVA_DB_PW}";
GRANT ALL PRIVILEGES ON nova.* TO "nova"@"%" \
  IDENTIFIED BY "${NOVA_DB_PW}";
EOF

echo_info "Creating nova service and endpoints"
openstack user create --domain default --password $NOVA_PW nova
openstack role add --project service --user nova admin

openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create --region RegionOne compute public http://${TRIX_CTRL_HOSTNAME}:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute internal http://${TRIX_CTRL_HOSTNAME}:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute admin http://${TRIX_CTRL_HOSTNAME}:8774/v2.1/%\(tenant_id\)s

echo_info "Setting up nova configuration files"
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf api_database connection "mysql+pymysql://nova:${NOVA_DB_PW}@127.0.0.1/nova_api"
openstack-config --set /etc/nova/nova.conf database connection "mysql+pymysql://nova:${NOVA_DB_PW}@127.0.0.1/nova"
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host $TRIX_CTRL_HOSTNAME
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password $OS_RMQ_PW
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://${TRIX_CTRL_HOSTNAME}:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://${TRIX_CTRL_HOSTNAME}:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers ${TRIX_CTRL_HOSTNAME}:11211
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password $NOVA_PW
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $TRIX_CTRL_IP
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron True
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen '$my_ip'
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address '$my_ip'
openstack-config --set /etc/nova/nova.conf glance api_servers http://${TRIX_CTRL_HOSTNAME}:9292
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

echo_info "Initializing the nova database"
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

echo_info "Starting the nova services"
systemctl enable openstack-nova-api.service
systemctl enable openstack-nova-consoleauth.service
systemctl enable openstack-nova-scheduler.service
systemctl enable openstack-nova-conductor.service
systemctl enable openstack-nova-novncproxy.service

systemctl restart openstack-nova-api.service
systemctl restart openstack-nova-consoleauth.service
systemctl restart openstack-nova-scheduler.service
systemctl restart openstack-nova-conductor.service
systemctl restart openstack-nova-novncproxy.service

echo_info "Saving passwords"
store_password NOVA_DB_PW $NOVA_DB_PW
store_password NOVA_PW $NOVA_PW
