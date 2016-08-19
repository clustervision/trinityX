#!/bin/bash

display_var TRIX_CTRL_HOSTNAME

function error {
    rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} delete_user openstack || true
    exit 1
}

trap error ERR

OS_RMQ_PW="$(get_password "$OS_RMQ_PW")"

echo_info "Starting rabbitmq-server"
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service

echo_info "Setting up a rabbitmq user for openstack"
rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} add_user openstack $OS_RMQ_PW
rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} set_permissions openstack ".*" ".*" ".*"

echo_info "Saving passwords"
store_password OS_RMQ_PW $OS_RMQ_PW
