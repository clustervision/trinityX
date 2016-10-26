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


# Enable the NFS server and exports

SHARED_OPTS="${NFS_SHARED_OPTS:-ro,no_root_squash}"


echo_info 'Adding the shared export'

append_line "${TRIX_SHARED} (${SHARED_OPTS})" /etc/exports


if [[ "$NFS_HOME_OPTS" ]] ; then
    echo_info 'Adding the /home export'
    append_line "${TRIX_HOME} (${NFS_HOME_OPTS})" /etc/exports
    store_variable /etc/trinity.sh HOME_ON_NFS 1
fi


if [[ "$NFS_HOME_RPCCOUNT" ]] ; then
    echo_info 'Adjusting the number of threads for the NFS server'
    sed -i 's/[# ]*\(RPCNFSDCOUNT=\).*/\1'"${NFS_HOME_RPCCOUNT}"'/g' /etc/sysconfig/nfs
fi
