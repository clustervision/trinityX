
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


# Set up the NFS mount from the nodes

display_var TRIX_{CTRL_HOSTNAME,SHARED,HOME} \
            NFS_EXPORT_{SHARED,HOME} NFS_ENABLE_RDMA



# Support NFS-over-RDMA if the server was configured that way

flag_is_set NFS_ENABLE_RDMA && proto=rdma || proto=tcp


sharedopts="nfs    defaults,nfsvers=4,ro,rsize=65536,wsize=65536,retrans=4,proto=${proto}    0  0"
homeopts="nfs    defaults,nfsvers=4,rw,rsize=65536,wsize=65536,retrans=4,noatime,proto=${proto}    0  0"


append_line /etc/fstab '#  ----  Trinity NFS mounts  ----'

if flag_is_set NFS_EXPORT_SHARED ; then
    append_line /etc/fstab "${TRIX_CTRL_HOSTNAME}:${TRIX_SHARED}    $TRIX_SHARED    $sharedopts"
fi

if flag_is_set NFS_EXPORT_HOME ; then
    append_line /etc/fstab "${TRIX_CTRL_HOSTNAME}:${TRIX_HOME}    $TRIX_HOME    $homeopts"
fi

