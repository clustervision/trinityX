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


display_var OS_{CTRL_HOSTNAME,COMPUTE_TUN_NIC} NEUTRON_USE_OPENVSWITCH

NEUTRON_PW="$(get_password "$NEUTRON_PW")"
OS_RMQ_PW="$(get_password "$OS_RMQ_PW")"

echo_info "Setting up neutron configuration files"
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host $OS_CTRL_HOSTNAME
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $OS_RMQ_PW
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://${OS_CTRL_HOSTNAME}:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://${OS_CTRL_HOSTNAME}:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers ${OS_CTRL_HOSTNAME}:11211
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password $NEUTRON_PW
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

openstack-config --set /etc/nova/nova.conf neutron url http://${OS_CTRL_HOSTNAME}:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://${OS_CTRL_HOSTNAME}:35357
openstack-config --set /etc/nova/nova.conf neutron auth_type password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password $NEUTRON_PW

if flag_is_set NEUTRON_USE_OPENVSWITCH; then
    echo_info "Using neutron with openvswitch"

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid

    echo_info "Setting up systemd to set correct IPs for neutron on image boot"

    mkdir /usr/lib/systemd/system/neutron-openvswitch-agent.service.d/
    cat > /usr/lib/systemd/system/neutron-openvswitch-agent.service.d/ip.conf <<-EOF
	[Service]
	PermissionsStartOnly=true
	ExecStartPre=-/bin/bash -c 'IP=\$(source /opt/nic; cat /etc/sysconfig/network-scripts/ifcfg-\$NODE_TUN_NIC | grep IPADDR | cut -d= -f2); \
	                            openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip \$IP'
	EOF

    echo_info "Enabling neutron-openvswitch agent"
    systemctl enable neutron-openvswitch-agent.service

else
    echo_info "Using neutron with linuxbridge"

    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan True
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population True
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
    openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

    echo_info "Setting up systemd to set correct IPs for neutron on image boot"

    mkdir /usr/lib/systemd/system/neutron-linuxbridge-agent.service.d/
    cat > /usr/lib/systemd/system/neutron-linuxbridge-agent.service.d/ip.conf <<-EOF
	[Service]
	PermissionsStartOnly=true
	ExecStartPre=-/bin/bash -c 'IP=\$(source /opt/nic; cat /etc/sysconfig/network-scripts/ifcfg-\$NODE_TUN_NIC | grep IPADDR | cut -d= -f2); \
	                            openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip \$IP'
	EOF

    echo_info "Enabling neutron-linuxbridge agent"
    systemctl enable neutron-linuxbridge-agent.service
fi

echo_info "Saving interface roles in /opt/nic on the image"
echo "export NODE_TUN_NIC=$OS_COMPUTE_TUN_NIC" >> /opt/nic

