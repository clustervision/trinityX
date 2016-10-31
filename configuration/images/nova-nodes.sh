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


display_var OS_CTRL_{HOSTNAME,IP} OS_COMPUTE_MGMT_NIC

NOVA_PW="$(get_password "$NOVA_PW")"
OS_RMQ_PW="$(get_password "$OS_RMQ_PW")"

echo_info "Setting up nova configuration files"
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host $OS_CTRL_HOSTNAME
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password $OS_RMQ_PW
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://${OS_CTRL_HOSTNAME}:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://${OS_CTRL_HOSTNAME}:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers ${OS_CTRL_HOSTNAME}:11211
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password $NOVA_PW
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron True
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf vnc enabled True
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address  '$my_ip'
openstack-config --set /etc/nova/nova.conf vnc novncproxy_base_url http://${OS_CTRL_IP}:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf glance api_servers http://${OS_CTRL_HOSTNAME}:9292
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) -eq 0 ]]; then
    openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
fi

echo_info "Setting up systemd to set correct IPs for nova on image boot"

mkdir /usr/lib/systemd/system/openstack-nova-compute.service.d
cat > /usr/lib/systemd/system/openstack-nova-compute.service.d/ip.conf << EOF
[Service]
PermissionsStartOnly=true
ExecStartPre=-/bin/bash -c 'IP=\$(source /opt/nic; cat /etc/sysconfig/network-scripts/ifcfg-\$NODE_MGMT_NIC | grep IPADDR | cut -d= -f2); \
                            openstack-config --set /etc/nova/nova.conf DEFAULT my_ip \$IP'
EOF

echo_info "Saving interface roles in /opt/nic on image"
echo "export NODE_MGMT_NIC=$OS_COMPUTE_MGMT_NIC" >> /opt/nic

echo_info "Enabling nova-compute and dependency services"
systemctl enable libvirtd.service
systemctl enable openstack-nova-compute.service

