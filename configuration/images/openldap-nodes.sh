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


# --------------------------------------

# Enable ldap over SSL

echo_info "Configuring ldap clients to trust the cluster's CA certificate"

cp -f ${TRIX_LOCAL}/certs/cluster-ca.crt /etc/openldap/certs/
append_line /etc/openldap/ldap.conf "TLS_CACERT   /etc/openldap/certs/cluster-ca.crt"

