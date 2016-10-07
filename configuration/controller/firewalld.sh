#!/bin/bash

# Basic configuration of firewalld, without TUI

display_var FWD_{PUBLIC_IF,TRUSTED_IF,NAT_PUBLIC,HTTPS_PUBLIC}


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
        ifcfg="/etc/sysconfig/network-scripts/ifcfg-${i}"
        if [[ -r "$ifcfg" ]] ; then
            echo_info "Assigning interfaces: $i -> Public"
            firewall-cmd --zone=public --change-interface=${i}
            #firewall-cmd --permanent --zone=public --change-interface=${i}
            store_system_variable "$ifcfg" NM_CONTROLLED no
            store_system_variable "$ifcfg" ZONE public
        else
            echo_warn "Interface $i doesn't have an ifcfg file, skipping..."
        fi
    done
fi

if flag_is_set FWD_TRUSTED_IF ; then
    for i in $FWD_TRUSTED_IF ; do
        ifcfg="/etc/sysconfig/network-scripts/ifcfg-${i}"
        if [[ -r "$ifcfg" ]] ; then
            echo_info "Assigning interfaces: $i -> Trusted"
            firewall-cmd --zone=trusted --change-interface=${i}
            #firewall-cmd --permanent --zone=trusted --change-interface=${i}
            store_system_variable "$ifcfg" NM_CONTROLLED no
            store_system_variable "$ifcfg" ZONE trusted
        else
            echo_warn "Interface $i doesn't have an ifcfg file, skipping..."
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

# Enable HTTPS on public zone

if flag_is_set FWD_HTTPS_PUBLIC ; then
    echo_info "Enabling HTTPS on the public zone"
    firewall-cmd --zone=public --add-service=https
    firewall-cmd --permanent --zone=public --add-service=https
fi


#---------------------------------------

echo_info 'Reloading firewalld'

firewall-cmd --reload

