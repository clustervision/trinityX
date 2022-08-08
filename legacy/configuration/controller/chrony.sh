
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


# Chrony (time server) configuration

display_var CHRONY_{UPSTREAM,SERVER} TRIX_CTRL{1,2}_HOSTNAME


if flag_is_set CHRONY_UPSTREAM ; then
    
    echo_info 'Setting up upstream time servers'
    
    # disable existing servers
    sed -i 's/^\(server .*\)/#\1/g' /etc/chrony.conf
    
    append_line /etc/chrony.conf '#  ----  Trinity machines  ----'
    
    # if no server was specified, this is client mode so use the controllers
    if ! [[ "$CHRONY_UPSTREAM" ]] ; then
        CHRONY_UPSTREAM="$TRIX_CTRL1_HOSTNAME $TRIX_CTRL2_HOSTNAME"
    fi
    
    # and add our own
    for i in ${CHRONY_UPSTREAM[@]} ; do
        append_line /etc/chrony.conf "server $i iburst"
    done
    
    modified=1
fi


if flag_is_set CHRONY_SERVER ; then
    
    echo_info 'Enabling client access'
    
    # start with disabling what may be leftovers from a previous installation
    sed -i 's/^\(allow.*\)/#\1/g' /etc/chrony.conf
    
    append_line /etc/chrony.conf '#  ----  Trinity machines  ----'
    
    if [[ "$CHRONY_SERVER" == 1 ]] ; then
        append_line /etc/chrony.conf "allow"
    else
        for i in ${CHRONY_SERVER[@]} ; do
            append_line /etc/chrony.conf "allow $i"
        done
    fi
fi


echo_info 'Enabling and restarting chronyd'

systemctl enable chronyd
flag_is_unset POST_CHROOT && systemctl restart chronyd || true

