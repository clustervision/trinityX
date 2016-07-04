#!/bin/bash

source /etc/trinity.sh


echo '*** Creating the SSSD configuration file'

sed "s,{{ controller }},${TRIX_CTRL_HOSTNAME}," "${POST_FILEDIR}"/sssd.conf > /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf


echo '*** Enabling and starting the service'

systemctl enable sssd
systemctl start sssd

authconfig --enablemkhomedir --enablesssd --enablesssdauth --update

