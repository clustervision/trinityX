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


# Enable RDMA on interfaces that support it, with the default package included
# in the CentOS distribution.

# You may want to disable this post script if the vendor software stack for your
# hardware contains those functionalities.

echo_info 'Enabling and starting the RDMA services'

systemctl enable rdma rdma-ndd

# The restart fails but the start behaves like a restart, so...
if flag_is_unset POST_CHROOT ; then
    systemctl start rdma && systemctl restart rdma-ndd
else
    true
fi

