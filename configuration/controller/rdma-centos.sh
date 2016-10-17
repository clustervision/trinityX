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


# Enable RDMA on interfaces that support it, with the default package included
# in the CentOS distribution.

# You will want to disable this post script if you're using a HW-specific RDMA
# configuration.

echo_info 'Enabling and starting the RDMA service'

systemctl enable rdma
# The restart fails but the start behaves like a restart, so...
flag_is_unset POST_CHROOT && systemctl start rdma || true

