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


# Post script to set up the NFS server on the controller

display_var NFS_{SHARED_OPTS,HOME_OPTS,HOME_RPCCOUNT}


# Enable the NFS server and exports

SHARED_OPTS="${NFS_SHARED_OPTS:-ro,no_root_squash}"


echo_info 'Adding the NFS shared export'

append_line /etc/exports "${TRIX_SHARED} *(${SHARED_OPTS})"


if flag_is_set NFS_HOME_OPTS ; then
    echo_info 'Adding the NFS home export'
    append_line /etc/exports "${TRIX_HOME} *(${NFS_HOME_OPTS})"
    store_variable "$TRIX_SHFILE" HOME_ON_NFS 1
fi


if flag_is_set NFS_HOME_RPCCOUNT ; then
    echo_info 'Adjusting the number of threads for the NFS server'
    sed -i 's/[# ]*\(RPCNFSDCOUNT=\).*/\1'"${NFS_HOME_RPCCOUNT}"'/g' /etc/sysconfig/nfs
fi


echo_info 'Enabling and starting the NFS server'

systemctl enable nfs-server
systemctl restart nfs-server

