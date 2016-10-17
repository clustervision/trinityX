#!/bin/bash

######################################################################
# Trinity X
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


display_var TRIX_CTRL_HOSTNAME

echo_info 'Creating the SSSD configuration file'

sed "s,{{ controller }},${TRIX_CTRL_HOSTNAME}," "${POST_FILEDIR}"/sssd.conf > /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf


echo_info 'Enabling and starting the service'

systemctl enable sssd
flag_is_unset POST_CHROOT && systemctl restart sssd

echo_info 'Setting up the system to use sssd for authentication'
authconfig --enablemkhomedir --enablesssd --enablesssdauth --update

