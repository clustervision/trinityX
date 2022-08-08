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


# Basic configuration of firewalld, without TUI

display_var FWD_{PUBLIC_IF,TRUSTED_IF,NAT_PUBLIC,TCP_PUBLIC,UDP_PUBLIC}


# This is a patch for some errors of the type:
# ERROR: Exception DBusException: org.freedesktop.DBus.Error.AccessDenied

if flag_is_unset POST_CHROOT ; then
    echo_info 'Restarting some services, strange messages are normal'

    systemctl daemon-reexec
    systemctl restart dbus polkit sshd systemd-logind
fi


# So we want firewalld. Enable and start it now, otherwise lots of commands will
# fail later.

echo_info 'Starting firewalld'

# CENTOS 7: the version of firewalld included in the distribution has a bug that
# blocks localhost traffic when using NAT set up with firewall-cmd.
# https://bugzilla.redhat.com/show_bug.cgi?id=904098
# https://bugzilla.redhat.com/show_bug.cgi?id=1326130
#
# This hacky solution is to circumvent this issue specific to 0.3.9+ (fixed in 4.0)
# Fix the masquerading rule criteria: it should be '! -o lo' instead of '! -i lo'

if [[ $(rpm -qa | grep firewalld-0.3) ]]; then
    FILE="/usr/lib/python2.7/site-packages/firewall/core/fw_zone.py"
    sed -i 's#\(rules.append((ipv, \[ "%s_allow" % (target), "!", "-\)i\(", "lo",\)#\1o\2#' $FILE
fi

systemctl enable firewalld
systemctl restart firewalld


#---------------------------------------

# Assign the various interfaces to their zones

# In a perfect world, the permanent configuration would be set with the
# --permanent option to firewall-cmd. But in the case of the version shipping
# with CentOS 7, it's just broken and the permanent config is ignored. So we
# need to store the permanent zone in the ifcfg files...

if flag_is_set FWD_PUBLIC_IF ; then
    for i in $FWD_PUBLIC_IF ; do
        echo_info "Assigning interfaces: $i -> Public"
        firewall-cmd --zone=public --change-interface=${i}
        firewall-cmd --permanent --zone=public --change-interface=${i}

        ifcfg="/etc/sysconfig/network-scripts/ifcfg-${i}"
        if [[ -r "$ifcfg" ]] ; then
            store_system_variable "$ifcfg" NM_CONTROLLED no
            store_system_variable "$ifcfg" ZONE public
        else
            echo_warn "Interface $i doesn't have an ifcfg file, skipping file update..."
        fi
    done
fi

if flag_is_set FWD_TRUSTED_IF ; then
    for i in $FWD_TRUSTED_IF ; do
        echo_info "Assigning interfaces: $i -> Trusted"
        firewall-cmd --zone=trusted --change-interface=${i}
        firewall-cmd --permanent --zone=trusted --change-interface=${i}

        ifcfg="/etc/sysconfig/network-scripts/ifcfg-${i}"
        if [[ -r "$ifcfg" ]] ; then
            store_system_variable "$ifcfg" NM_CONTROLLED no
            store_system_variable "$ifcfg" ZONE trusted
        else
            echo_warn "Interface $i doesn't have an ifcfg file, skipping file update..."
            fi
    done
fi


#---------------------------------------

# Set up masquerading

if flag_is_set FWD_NAT_PUBLIC ; then
    echo_info "Enabling NAT on the public zone"

    firewall-cmd --zone=public --add-masquerade
    firewall-cmd --permanent --zone=public --add-masquerade
fi


#---------------------------------------

# Enable required ports on the public zone

echo_info "Allowing TCP ports on the public zone"

for range in ${FWD_TCP_PUBLIC[*]}; do
    firewall-cmd --permanent --zone=public --add-port="$range"/tcp
done

echo_info "Allowing UDP ports on the public zone"

for range in ${FWD_UDP_PUBLIC[*]}; do
    firewall-cmd --permanent --zone=public --add-port="$range"/udp
done


#---------------------------------------

echo_info 'Reloading firewalld'

firewall-cmd --reload

