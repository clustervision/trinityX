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


display_var TRIX_CTRL_HOSTNAME {CTRL,COMPUTE}_ALLOWED_GROUPS

echo_info 'Creating the SSSD configuration file'

sed "s,{{ controller }},${TRIX_CTRL_HOSTNAME}," "${POST_FILEDIR}"/sssd.conf > /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf


# -----------------------------------
#
# Generate an ldap access filter based on the *_ALLOWED_GROUPS options
# and create those groups on the controllers.
#

echo_info 'Setting up access controle'

SLAPD_ROOT_PW="$(get_password "$SLAPD_ROOT_PW")"

if flag_is_unset POST_CHROOT ; then

    ALLOWED_GROUPS=$CTRL_ALLOWED_GROUPS

else

    ALLOWED_GROUPS=$COMPUTE_ALLOWED_GROUPS

fi

FILTER="(|"

for GRP in $ALLOWED_GROUPS; do

    flag_is_unset POST_CHROOT && obol -w $SLAPD_ROOT_PW group add $GRP

    FILTER+="(memberOf=cn=$GRP,ou=group,dc=local)"

done

FILTER+=")"

sed -i "s/{{ access_filter }}/${FILTER}/" /etc/sssd/sssd.conf


# -----------------------------------
#
# Enable sssd and setup the system to use it
#

echo_info 'Enabling and starting the service'

systemctl enable sssd
flag_is_unset POST_CHROOT && systemctl restart sssd

echo_info 'Setting up the system to use sssd for authentication'
authconfig --enablemkhomedir --enablesssd --enablesssdauth --update

