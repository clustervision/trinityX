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

display_var HA

if flag_is_set HA && flag_is_set PRIMARY_INSTALL; then

    echo_info "Setting up a shared docker-registry between the controllers"

    if [[ $(ls -A  "${TRIX_LOCAL}/docker-registry" &>/dev/null) ]]; then
        echo_warn "Found an existing shared registry. Backing it up in "${TRIX_LOCAL}/docker-registry.bkp""
        mv ${TRIX_LOCAL}/docker-registry{,.bkp}
    fi

    mkdir -p "${TRIX_LOCAL}/docker-registry"

    mv "/var/lib/docker-registry/*" "${TRIX_LOCAL}/docker-registry/" 2>/dev/null || true

fi

flag_is_set HA && ln -sfn "${TRIX_LOCAL}/docker-registry" "/var/lib/docker-registry"

echo_info 'Enabling and starting docker-registry'

systemctl enable docker-registry
systemctl restart docker-registry

