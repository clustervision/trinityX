#!/bin/bash

display_var TRIX_CTRL_HOSTNAME

echo_info 'Creating the SSSD configuration file'

sed "s,{{ controller }},${TRIX_CTRL_HOSTNAME}," "${POST_FILEDIR}"/sssd.conf > /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf


echo_info 'Enabling and starting the service'

systemctl enable sssd
flag_is_unset POST_CHROOT && systemctl restart sssd

echo_info 'Setting up the system to use sssd for authentication'
authconfig --enablemkhomedir --enablesssd --enablesssdauth --update

