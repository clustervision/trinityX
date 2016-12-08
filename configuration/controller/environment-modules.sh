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


# Environment modules setup

if flag_is_unset POST_CHROOT && \
   ! ( flag_is_set HA && flag_is_unset PRIMARY_INSTALL ) ; then
    
    echo_info 'Creating the shared modules directories'
    
    # Contents of the shared modulefiles directory:
    # /trinity/shared/
    # `-- modulefiles
    #     |-- cv-advanced       advanced CV modules, not available by default
    #     ¦-- cv-standard       standard CV modules, available by default
    #     |-- site-local        site-local modules, available by default
    #      -- modulegroups      modulefiles to load groups (advanced, local, etc)
    
    mkdir -p "${TRIX_SHARED_MODFILES}/modulegroups"
    mkdir -p "${TRIX_SHARED_MODFILES}/cv-standard"
    mkdir -p "${TRIX_SHARED_MODFILES}/cv-advanced"
    mkdir -p "${TRIX_SHARED_MODFILES}/site-local"
    
    
    echo_info 'Adding the group modulefiles'
    
    cp "${POST_FILEDIR}/cv-advanced" "${TRIX_SHARED_MODFILES}/modulegroups"
    
    
    echo_info 'Adjusting the TrinityX installation path'
    
    sed -i 's#TRIX_ROOT#'"$TRIX_ROOT"'#g' "${TRIX_SHARED_MODFILES}/modulegroups/"*
fi


echo_info 'Adding the group path to the default configuration'

dest='/usr/share/Modules/init/.modulespath'

append_line "$dest" "${TRIX_SHARED_MODFILES}/modulegroups"
append_line "$dest" "${TRIX_SHARED_MODFILES}/cv-standard"
append_line "$dest" "${TRIX_SHARED_MODFILES}/site-local"

append_line "$dest" "${TRIX_LOCAL_MODFILES}"

