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


display_var TRIX_CTRL{1,2,}_{HOSTNAME,IP}

#---------------------------------------

echo_info "Check if remote host is available."
/usr/bin/ssh ${TRIX_CTRL2_IP} hostname || (echo_error "Unable to connect to ${TRIX_CTRL2_IP}"; exit 1)

#---------------------------------------

echo_info "Copy /etc/hosts to ${TRIX_CTRL2_HOSTNAME}"

/usr/bin/scp /etc/hosts ${TRIX_CTRL2_IP}:/etc/hosts

#---------------------------------------

# Add floating IP to this controller if it is not present already

if [[ -z $(ip addr show to $TRIX_CTRL_IP) ]]; then

    echo_info "Find out which interface owns ${TRIX_CTRL1_IP}"
    
    TMPVAR=$(/usr/sbin/ip a show to ${TRIX_CTRL1_IP} | awk 'NR==1{print $2}')
    CTRL1_IF=${TMPVAR%:}
    
    echo "${CTRL1_IF:?"Could not find interface."}"
    
    echo_info "Assign floating IP"
    
    eval $(/usr/bin/ipcalc -np $(/usr/sbin/ip a show to  ${TRIX_CTRL1_IP} | /usr/bin/awk 'NR==2{print $2}') | /usr/bin/awk '{print "CTRL_IP_"$0}')
    echo "CTRL_IP_PREFIX=${CTRL_IP_PREFIX:?"Unable to find"}"

    /usr/sbin/ip a add ${TRIX_CTRL_IP}/${CTRL_IP_PREFIX} dev ${CTRL1_IF}

else

    echo_info "Floating IP already assigned. Skipping."

fi

