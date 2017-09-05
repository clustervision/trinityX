#!/bin/bash

######################################################################
# TrinityX
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


display_var LUNA_{GROUP,USER}_ID

echo_info "Delete luna user if exists."

if /usr/bin/id -u luna >/dev/null 2>&1; then
    /usr/sbin/userdel luna

fi
if /usr/bin/grep -q -E "^luna:" /etc/group ; then
    /usr/sbin/groupdel luna
fi

echo_info "Add users and create folders."

/usr/sbin/groupadd -r ${LUNA_GROUP_ID:+"-g $LUNA_GROUP_ID"} luna
store_variable "${TRIX_SHFILE}" LUNA_GROUP_ID $(/usr/bin/getent group | /usr/bin/awk -F\: '$1=="luna"{print $3}')

/usr/sbin/useradd -r ${LUNA_USER_ID:+"-u $LUNA_USER_ID"} -g luna -d ${TRIX_LOCAL}/luna luna
store_variable "${TRIX_SHFILE}" LUNA_USER_ID $(/usr/bin/id -u luna)

