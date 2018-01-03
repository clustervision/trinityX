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


display_var TRIX_CTRL_HOSTNAME

echo_info "Configuring docker to use the controller's insecure registry"

append_line /etc/sysconfig/docker "INSECURE_REGISTRY=\"--insecure-registry ${TRIX_CTRL_HOSTNAME}:5000\""

if flag_is_set POST_CHROOT; then
    echo_info "Disabling the default creation of the docker0 bridge on compute nodes"
    append_line /etc/sysconfig/docker-network "DOCKER_NETWORK_OPTIONS=\"--bridge=none\""
fi

echo_info 'Enabling and starting docker daemeon'

flag_is_unset POST_CHROOT && systemctl restart docker
systemctl enable docker

echo_info 'Installing mpi-drun and dependencies'

gcc -O2 -o /usr/local/bin/mpi-drun ${POST_FILEDIR}/mpi-drun.c
cp ${POST_FILEDIR}/mpi-drun.sh /usr/local/bin/
cp ${POST_FILEDIR}/mpi-dclean /usr/local/bin/

chmod 4755 /usr/local/bin/mpi-drun
chmod 755 /usr/local/bin/mpi-drun.sh
chmod 700 /usr/local/bin/mpi-dclean

