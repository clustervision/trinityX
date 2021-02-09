
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


# Setup the hosts files on the nodes
# The base TrinityX setup must have been done, and we're using /etc/trinity.sh
# for the IPs of the controllers.

display_var TRIX_CTRL{1,2,}_{HOSTNAME,IP}
flag_is_set OS_CTRL_HOSTNAME && display_var OS_CTRL_{HOSTNAME,IP}


append_line /etc/hosts '#  ----  Trinity machines  ----'

for i in TRIX_CTRL{1,2,_} OS_CTRL; do

    ctrlname=${i}_HOSTNAME

    if flag_is_set $ctrlname ; then
        ctrlname=${!ctrlname}
        ctrlip=${i}_IP ; ctrlip=${!ctrlip}

        append_line /etc/hosts "$ctrlip  $ctrlname"
    fi
done

