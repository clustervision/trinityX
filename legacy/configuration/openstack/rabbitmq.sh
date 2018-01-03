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

function error {
    rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} delete_user openstack || true
    exit 1
}

trap error ERR

OS_RMQ_PW="$(get_password "$OS_RMQ_PW")"

echo_info "Starting rabbitmq-server"
systemctl enable rabbitmq-server.service
systemctl restart rabbitmq-server.service

echo_info "Setting up a rabbitmq user for openstack"
rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} add_user openstack $OS_RMQ_PW
rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} set_permissions openstack ".*" ".*" ".*"

echo_info "Saving passwords"
store_password OS_RMQ_PW $OS_RMQ_PW
