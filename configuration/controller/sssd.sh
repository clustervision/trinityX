#!/bin/bash

source /etc/trinity.sh


echo_info 'Creating the SSSD configuration file'

sed "s,{{ controller }},${TRIX_CTRL_HOSTNAME}," "${POST_FILEDIR}"/sssd.conf > /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf


echo_info 'Enabling and starting the service'

systemctl enable sssd
systemctl restart sssd

authconfig --enablemkhomedir --enablesssd --enablesssdauth --update

