#!/bin/bash

# Initialize configuration file
sed "s,{{ controller }},$CONTROLLER_HOSTNAME," sssd/sssd.conf > /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf

systemctl enable sssd
systemctl start sssd

authconfig --enablemkhomedir --enablesssd --enablesssdauth --update

