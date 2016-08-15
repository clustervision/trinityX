#!/bin/bash

echo_info 'Enabling and starting docker-registry'

systemctl enable docker-registry
systemctl start docker-registry

