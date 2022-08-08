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


display_var TRIX_CTRL_{IP,HOSTNAME}

echo_info "Configure zabbix-agent"

sed -i -e "s,^\(Server=\).*,\1${TRIX_CTRL_IP}," /etc/zabbix/zabbix_agentd.conf
sed -i -e "s,^\(ServerActive=\).*,\1${TRIX_CTRL_IP}," /etc/zabbix/zabbix_agentd.conf
sed -i -e "s,^\(Hostname=.*\),# \1," /etc/zabbix/zabbix_agentd.conf

echo_info "Enable zabbix-agent service"

systemctl enable zabbix-agent

flag_is_unset POST_CHROOT && systemctl restart zabbix-agent || true

