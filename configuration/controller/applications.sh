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


# Script to add provided application modules to the system
# All modulefiles are located in separate directories usign the format
#
# POST_FILEDIR/GROUP/module/version/modulefile
#
# The script will copy all available modules to their appropriate location
#
# Modulefiles should assume that the application will be installed in:
#
# {{ prefix }}/applications/module/version
# 
# This script will replace {{ prefix }} with the correct value
#


if flag_is_set HA && flag_is_unset PRIMARY_INSTALL ; then

    echo_info 'Secondary installation, nothing to do.'
    exit 0
fi


for GROUP in 'cv-standard' 'cv-advanced' 'site-local'; do

    echo_info "Adding $GROUP module files to the system"

    for MOD in ${POST_FILEDIR}/${GROUP}/*; do
    
        [[ -e "$MOD" ]] || continue;
    
        MODULE=$(basename "$MOD");
        VERSION=$(ls "${POST_FILEDIR}/${GROUP}/${MODULE}");
        echo_info "Adding ${MODULE}/${VERSION} to $GROUP";

        cp -r "$MOD" "${TRIX_SHARED_MODFILES}/${GROUP}/"
        sed -i -e "s,{{ prefix }},$TRIX_SHARED," "${TRIX_SHARED_MODFILES}/${GROUP}/${MODULE}/${VERSION}/modulefile"

    done

done

