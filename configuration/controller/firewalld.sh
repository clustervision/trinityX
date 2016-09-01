#!/bin/bash

# Basic configuration of firewalld, without TUI

display_var FWD_{PUBLIC_IF,TRUSTED_IF,NAT_PUBLIC,HTTPS_PUBLIC}


# So we want firewalld. Enable and start it now, otherwise lots of commands will
# fail later.

echo_info 'Starting firewalld'

systemctl enable firewalld
systemctl restart firewalld


#---------------------------------------

# Assign the various interfaces to their zones

if flag_is_set FWD_PUBLIC_IF ; then
    for i in $FWD_PUBLIC_IF ; do
        echo_info "Assigning interfaces: $i -> Public"
        firewall-cmd --zone=public --change-interface=${i}
        firewall-cmd --zone=public --change-interface=${i} --permanent
    done
fi

if flag_is_set FWD_TRUSTED_IF ; then
    for i in $FWD_TRUSTED_IF ; do
        echo_info "Assigning interfaces: $i -> Trusted"
        firewall-cmd --zone=trusted --change-interface=${i}
        firewall-cmd --zone=trusted --change-interface=${i} --permanent
    done
fi


#---------------------------------------

# Set up masquerading

if flag_is_set FWD_NAT_PUBLIC ; then
    echo_info "Enabling NAT on the public zone"

    # CENTOS 7: the version of firewalld included in the distribution has a bug that
    # blocks localhost traffic when using NAT set up with firewall-cmd.
    # https://bugzilla.redhat.com/show_bug.cgi?id=904098
    # https://bugzilla.redhat.com/show_bug.cgi?id=1326130

    # Enable NAT using iptables rules
    firewall-cmd --direct --add-rule ipv4 filter FWDO_public_allow 0 -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 nat POST_public_allow 0 ! -o lo -j MASQUERADE
    firewall-cmd --permanent --direct --add-rule ipv4 filter FWDO_public_allow 0 -j ACCEPT
    firewall-cmd --permanent --direct --add-rule ipv4 nat POST_public_allow 0 ! -o lo -j MASQUERADE

    # firewall-cmd --zone=public --add-masquerade
    # firewall-cmd --permanent --zone=public --add-masquerade
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

