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


display_var TRIX_CTRL_HOSTNAME NEUTRON_{EXT_NIC,TUN_IP,USE_OPENVSWITCH}

function error {
    openstack user delete neutron
    openstack service delete neutron

    for e in $(openstack endpoint list | grep network | cut -d '|' -f2); do
        openstack endpoint delete $e;
    done

    mysqladmin -uroot -p$MYSQL_ROOT_PASSWORD -f drop neutron || true
    systemctl kill -s SIGKILL neutron-server.service || true
    systemctl kill -s SIGKILL neutron-dhcp-agent.service || true
    systemctl kill -s SIGKILL neutron-metadata-agent.service || true
    systemctl kill -s SIGKILL neutron-l3-agent.service || true
    systemctl kill -s SIGKILL neutron-openvswitch-agent.service || true
    systemctl kill -s SIGKILL neutron-linuxbridge-agent.service || true
    exit 1
}

trap error ERR

source /root/.admin-openrc

METADATA_SECRET=$(openssl rand -hex 10)
NEUTRON_PW="$(get_password "$NEUTRON_PW")"
NEUTRON_DB_PW="$(get_password "$NEUTRON_DB_PW")"

echo_info "Setting up the neutron database"

mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO "neutron"@"localhost" \
  IDENTIFIED BY "${NEUTRON_DB_PW}";
GRANT ALL PRIVILEGES ON neutron.* TO "neutron"@"%" \
  IDENTIFIED BY "${NEUTRON_DB_PW}";
EOF

echo_info "Creating the neutron service and endpoints"
openstack user create --domain default --password $NEUTRON_PW neutron
openstack role add --project service --user neutron admin

openstack service create --name neutron --description "OpenStack Networking" network

openstack endpoint create --region RegionOne network public http://${TRIX_CTRL_HOSTNAME}:9696
openstack endpoint create --region RegionOne network internal http://${TRIX_CTRL_HOSTNAME}:9696
openstack endpoint create --region RegionOne network admin http://${TRIX_CTRL_HOSTNAME}:9696

echo_info "Setting up neutron configuration files"
openstack-config --set /etc/neutron/neutron.conf database connection "mysql+pymysql://neutron:${NEUTRON_DB_PW}@127.0.0.1/neutron"
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host $TRIX_CTRL_HOSTNAME
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $OS_RMQ_PW
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://${TRIX_CTRL_HOSTNAME}:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://${TRIX_CTRL_HOSTNAME}:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers ${TRIX_CTRL_HOSTNAME}:11211
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password $NEUTRON_PW
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf nova auth_url http://${TRIX_CTRL_HOSTNAME}:35357
openstack-config --set /etc/neutron/neutron.conf nova auth_type password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_name default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_name default
openstack-config --set /etc/neutron/neutron.conf nova region_name RegionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name service
openstack-config --set /etc/neutron/neutron.conf nova username nova
openstack-config --set /etc/neutron/neutron.conf nova password $NOVA_PW
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks external
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver iptables_hybrid

openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge 

openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $TRIX_CTRL_HOSTNAME
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET

if flag_is_set NEUTRON_USE_OPENVSWITCH; then
    echo_info "Using neutron with openvswitch"
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $NEUTRON_TUN_IP
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings external:br-ex
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid
    
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver

else
    echo_info "Using neutron with linuxbridge"
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge,l2population

    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings external:$NEUTRON_EXT_NIC
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan True
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $NEUTRON_TUN_IP
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population True
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
fi

openstack-config --set /etc/nova/nova.conf neutron url http://${TRIX_CTRL_HOSTNAME}:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://${TRIX_CTRL_HOSTNAME}:35357
openstack-config --set /etc/nova/nova.conf neutron auth_type password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password $NEUTRON_PW
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $METADATA_SECRET

ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

echo_info "Initializing the neutron database"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

echo_info "Starting the neutron services and dependencies"
systemctl restart openstack-nova-api.service

systemctl enable neutron-server.service
systemctl enable neutron-dhcp-agent.service
systemctl enable neutron-metadata-agent.service
systemctl enable neutron-l3-agent.service

systemctl restart neutron-server.service
systemctl restart neutron-dhcp-agent.service
systemctl restart neutron-metadata-agent.service
systemctl restart neutron-l3-agent.service

if flag_is_set NEUTRON_USE_OPENVSWITCH; then
    systemctl enable openvswitch.service
    systemctl restart openvswitch.service

    ovs-vsctl --may-exist add-br br-ex
    ovs-vsctl --may-exist add-port br-ex $NEUTRON_EXT_NIC

    systemctl enable neutron-openvswitch-agent.service
    systemctl restart neutron-openvswitch-agent.service
else
    systemctl enable neutron-linuxbridge-agent.service
    systemctl restart neutron-linuxbridge-agent.service
fi

# Setup initial provider network
echo_info "Creating an initial neutron provider network (external)"
neutron net-create --shared --provider:physical_network external --provider:network_type flat external --router:external

echo_info "Saving passwords"
store_password NEUTRON_DB_PW $NEUTRON_DB_PW
store_password NEUTRON_PW $NEUTRON_PW
