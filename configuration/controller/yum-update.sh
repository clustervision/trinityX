#!/bin/bash

# Run yum update. It's really that simple.

echo_info 'Running yum update'

yum -y update

echo_info 'Restarting some services after the update'

if flag_is_unset POST_CHROOT ; then
    systemctl daemon-reexec
    systemctl restart dbus polkit sshd systemd-logind
fi

