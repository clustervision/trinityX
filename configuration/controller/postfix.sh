#!/bin/bash

display_var TRIX_CTRL_HOSTNAME

echo_info 'Configuring postfix'

postconf -e "myhostname = $(hostname)"
postconf -e "inet_interfaces = all"

echo_info 'Enabling and starting postfix'

systemctl enable postfix
systemctl restart postfix

