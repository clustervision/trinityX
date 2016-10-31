
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

display_var TRIX_{CTRL_HOSTNAME,SHARED,HOME} HOME_ON_NFS


# The shared directory is always mounted, the home dir is conditional

append_line /etc/fstab '#  ----  Trinity machines  ----'

common="nfs    defaults,rsize=32768,wsize=32768    0    0"

append_line /etc/fstab "${TRIX_CTRL_HOSTNAME}:${TRIX_SHARED}    $TRIX_SHARED    $common"

if flag_is_set HOME_ON_NFS ; then
    append_line /etc/fstab "${TRIX_CTRL_HOSTNAME}:${TRIX_HOME}    $TRIX_HOME    $common"
fi

