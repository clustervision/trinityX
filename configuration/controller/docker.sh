#!/bin/bash

display_var TRIX_CTRL_HOSTNAME

echo_info "Configuring docker to use the controller's insecure registry"

append_line /etc/sysconfig/docker "INSECURE_REGISTRY=\"--insecure-registry ${TRIX_CTRL_HOSTNAME}:5000\""

echo_info 'Enabling and starting docker daemeon'

flag_is_unset POST_CHROOT && systemctl start docker
systemctl enable docker

echo_info 'Installing mpi-drun and dependencies'

gcc -O2 -o /usr/local/bin/mpi-drun ${POST_FILEDIR}/mpi-drun.c
cp ${POST_FILEDIR}/mpi-drun.sh /usr/local/bin/
cp ${POST_FILEDIR}/mpi-dclean /usr/local/bin/

chmod 4755 /usr/local/bin/mpi-drun
chmod 755 /usr/local/bin/mpi-drun.sh
chmod 700 /usr/local/bin/mpi-dclean

