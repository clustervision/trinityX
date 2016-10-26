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


display_var TRIX_CTRL_HOSTNAME HORIZON_ALLOWED_HOSTS

echo_info "Configuring horizon"
CONF_FILE="/etc/openstack-dashboard/local_settings"

sed -i "s,^\(OPENSTACK_HOST =.*\),# \1," $CONF_FILE
append_line $CONF_FILE "OPENSTACK_HOST = \"${TRIX_CTRL_HOSTNAME}\""

sed -i "s%^\(ALLOWED_HOSTS =.*\)%# \1%" $CONF_FILE
append_line $CONF_FILE "ALLOWED_HOSTS = ${HORIZON_ALLOWED_HOSTS}"

sed -i "s,^\(SESSION_ENGINE =.*\),# \1," $CONF_FILE
append_line $CONF_FILE "SESSION_ENGINE = 'django.contrib.sessions.backends.cache'"

sed -i "s,^\(OPENSTACK_KEYSTONE_URL =.*\),# \1," $CONF_FILE
append_line $CONF_FILE "OPENSTACK_KEYSTONE_URL = \"http://%s:5000/v3\" % OPENSTACK_HOST"

sed -i "s,^\(OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT =.*\),# \1," $CONF_FILE
append_line $CONF_FILE "OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True"

sed -i "s,^\(OPENSTACK_KEYSTONE_DEFAULT_DOMAIN =.*\),# \1," $CONF_FILE
append_line $CONF_FILE "OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'default'"

sed -i "s,^\(OPENSTACK_KEYSTONE_DEFAULT_ROLE =.*\),# \1," $CONF_FILE
append_line $CONF_FILE "OPENSTACK_KEYSTONE_DEFAULT_ROLE = 'user'"

cat >> /etc/openstack-dashboard/local_settings <<EOF
CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': '${TRIX_CTRL_HOSTNAME}:11211',
    }
}

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}
EOF

echo_info "Restarting httpd and memcached"
systemctl restart httpd.service memcached.service

