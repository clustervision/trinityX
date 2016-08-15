#!/bin/bash

display_var TRIX_CTRL_HOSTNAME

echo_info "Configuring docker to use the controller's insecure registry"

append_line /etc/sysconfig/docker "INSECURE_REGISTRY=\"--insecure-registry ${TRIX_CTRL_HOSTNAME}:5000\""

echo_info 'Enabling and starting docker daemeon'

flag_is_unset CHROOT_INSTALL && systemctl start docker
systemctl enable docker

