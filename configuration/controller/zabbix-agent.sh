#!/bin/bash

display_var TRIX_CTRL_{IP,HOSTNAME}

echo_info "Configure zabbix-agent"

sed -i -e "s,^\(Server=\).*,\1${TRIX_CTRL_IP}," /etc/zabbix/zabbix_agentd.conf
sed -i -e "s,^\(ServerActive=\).*,\1${TRIX_CTRL_IP}," /etc/zabbix/zabbix_agentd.conf
sed -i -e "s,^\(Hostname=.*\),# \1," /etc/zabbix/zabbix_agentd.conf

echo_info "Enable zabbix-agent service"

systemctl enable zabbix-agent

flag_is_unset POST_CHROOT && systemctl restart zabbix-agent || true

