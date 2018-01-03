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


# Example post script

echo_info "The following parameters are available in the environment:"

display_var POST_TOPDIR \
            POST_CONFDIR \
            POST_CONFIG \
            POST_FILEDIR \
            POST_CHROOT


echo_info "The following parameters come from the specific configuration file (POST_CONFIG):"

display_var EXAMPLE_VALUE


if [[ -r /etc/trinity.sh ]] ; then

    echo_info "The following parameters come from \"/etc/trinity.sh\":"

    display_var TRIX_VERSION \
                TRIX_ROOT \
                TRIX_HOME \
                TRIX_IMAGES \
                TRIX_LOCAL{,_APPS,_MODFILES} \
                TRIX_SHARED{,_TMP,_APPS,_MODFILES} \
                TRIX_SHFILE \
                TRIX_SHADOW

    display_var HA \
                TRIX_CTRL{1,2,}_{HOSTNAME,IP}

else
    echo_warn "The file \"/etc/trinity.sh\" does not exist (yet) on this system."
    echo "\"/etc/trinity.sh\" is created during the TrinityX installation."
fi


if [[ -r /etc/trinity.local.sh ]] ; then
    
    echo_info "The following parameters come from \"/etc/trinity.local.sh\":"
    
    display_var PRIMARY_INSTALL
    
else
    echo_warn "The file \"/etc/trinity.local.sh\" does not exist (yet) on this system."
    echo "\"/etc/trinity.local.sh\" is created during the TrinityX installation."
fi


echo -n -e ${QUIET+"\nIf you read this, then the silent option (-q) is enabled.\n"}
echo -n -e ${VERBOSE+"\nIf you read this, then the verbose option (-v) is enabled.\n"}

echo_info "That's all folks!"

