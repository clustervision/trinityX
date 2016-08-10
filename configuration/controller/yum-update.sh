#!/bin/bash

# Run yum update. It's really that simple.

echo_info 'Running yum update'

yum -y update

echo_info 'Restarting some services after the update'

systemctl restart dbus polkit sshd systemd-logind

