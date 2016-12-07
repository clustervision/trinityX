
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


# Post script to detect if we're doing the installation on the first controller
# (called primary installation), or if we're only setting up the second
# controller (which assumes that the primary controller has already done most of
# the hard work).

display_var HA CTRL{1,2}_{HOSTNAME,IP}


#---------------------------------------
# Non-HA
#---------------------------------------

if flag_is_unset HA ; then

    echo_warn 'No HA support was requested, exiting.'
    exit
fi


#---------------------------------------
# HA, both
#---------------------------------------

# Don't pick up background noise

unset detected

# Loop over the interfaces and check if one IP matches either cfg values.
# Checking that the specified hostname matches the specified IP was done in the
# hosts PS.

for i in $(hostname -I) ; do

    case $i in

        $CTRL1_IP )
                echo_info 'CTRL1 found, proceeding with primary installation.'
                store_system_variable /etc/trinity.local.sh PRIMARY_INSTALL 1
                detected=1
                break
            ;;

        $CTRL2_IP )
                echo_info 'CTRL2 found, proceeding with secondary installation.'
                store_system_variable /etc/trinity.local.sh PRIMARY_INSTALL 0
                detected=1
                break
    esac
done


# And what if we didn't find the correct IP and HOSTNAME pair?

if flag_is_unset detected ; then
    echo_error ' This system does not match any of the IP and HOSTNAME pairs.

Please check the respective _IP and _HOSTNAME variables in the configuration
file, as well as the network and hostname configuration of the system.'
    exit 1
fi

