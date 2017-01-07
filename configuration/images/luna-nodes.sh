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


# Copy luna's dracut module to the image. The files are supposed to be located at
# ${TRIX_LOCAL}/luna/dracut/95luna

echo_info 'Installing luna dracut module'

if [[ -d "${TRIX_LOCAL}/luna/dracut/95luna" ]]; then
    cp -pr "${TRIX_LOCAL}/luna/dracut/95luna" "/usr/lib/dracut/modules.d/"
else
    echo_error 'Could not find the dracut module in ${TRIX_LOCAL}/luna/dracut/95luna'
fi

