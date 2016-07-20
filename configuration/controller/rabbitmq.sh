#!/bin/bash

source /etc/trinity.sh
source "$POST_CONFIG"

OS_RMQ_PW="$(get_password "$OS_RMQ_PW")"

store_password OS_RMQ_PW $OS_RMQ_PW

echo_info "Starting rabbitmq-server"
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service

echo_info "Setting up a rabbitmq user for openstack"
rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} add_user openstack $OS_RMQ_PW
rabbitmqctl -n rabbit@${TRIX_CTRL_HOSTNAME} set_permissions openstack ".*" ".*" ".*"

