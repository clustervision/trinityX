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


display_var MUNGE_{GROUP,USER}_ID SLURM_{GROUP,USER}_ID


for N in slurm munge; do
    if /usr/bin/id -u ${N} >/dev/null 2>&1; then
        /usr/sbin/userdel ${N}
    fi

    if /usr/bin/grep -q -E "^${N}:" /etc/group ; then
        /usr/sbin/groupdel ${N}
    fi
done

echo_info "Creating Slurm and Munge users"

/usr/sbin/groupadd -r ${MUNGE_GROUP_ID:+"-g $MUNGE_GROUP_ID"} munge 
store_variable "${TRIX_SHFILE}" MUNGE_GROUP_ID $(/usr/bin/getent group | awk -F\: '$1=="munge"{print $3}')

/usr/sbin/useradd -r ${MUNGE_USER_ID:+"-u $MUNGE_USER_ID"} -g munge -d /var/run/munge -s /sbin/nologin munge
store_variable "${TRIX_SHFILE}" MUNGE_USER_ID $(/usr/bin/id -u munge)

/usr/sbin/groupadd -r ${SLURM_GROUP_ID:+"-g $SLURM_GROUP_ID"} slurm
store_variable "${TRIX_SHFILE}" SLURM_GROUP_ID $(/usr/bin/getent group | awk -F\: '$1=="slurm"{print $3}')

/usr/sbin/useradd -r ${SLURM_USER_ID:+"-u $SLURM_USER_ID"} -g slurm -d /var/log/slurm  -s /sbin/nologin slurm
store_variable "${TRIX_SHFILE}" SLURM_USER_ID $(/usr/bin/id -u slurm)

/usr/bin/mkdir -p /var/log/slurm
/usr/bin/chown slurm:slurm /var/log/slurm
/usr/bin/chmod 750 /var/log/slurm

