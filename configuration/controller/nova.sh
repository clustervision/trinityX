#!/bin/bash

source /etc/trinity.sh
source "$POST_CONFIG"
source "${TRIX_SHADOW}"
source /root/.admin-openrc

NOVA_PW="$(get_password "$NOVA_PW")"
NOVA_DB_PW="$(get_password "$NOVA_DB_PW")"

store_password NOVA_DB_PW $NOVA_DB_PW
store_password NOVA_PW $NOVA_PW

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

systemctl start openstack-nova-api.service
systemctl start openstack-nova-consoleauth.service
systemctl start openstack-nova-scheduler.service
systemctl start openstack-nova-conductor.service
systemctl start openstack-nova-novncproxy.service

