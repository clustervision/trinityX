#!/bin/bash

# Basic configuration of firewalld, without TUI

source "$POST_CONFIG"


# So we want firewalld. Enable and start it now, otherwise lots of commands will
# fail later.

echo_info 'Starting firewalld'

systemctl enable firewalld
systemctl restart firewalld


#---------------------------------------

# Assign the various interfaces to their zones

if [[ "$FWD_PUBLIC_IF" ]] ; then
    for i in $FWD_PUBLIC_IF ; do
        echo_info "Assigning interfaces: $i -> Public"
        firewall-cmd --zone=public --change-interface=${i}
        firewall-cmd --zone=public --change-interface=${i} --permanent
    done
fi

if [[ "$FWD_TRUSTED_IF" ]] ; then
    for i in $FWD_TRUSTED_IF ; do
        echo_info "Assigning interfaces: $i -> Trusted"
        firewall-cmd --zone=trusted --change-interface=${i}
        firewall-cmd --zone=trusted --change-interface=${i} --permanent
    done
fi


#---------------------------------------

# Set up masquerading

if (( $FWD_NAT_PUBLIC )) ; then
    echo_info "Enabling NAT on the public zone"
    firewall-cmd --zone=public --add-masquerade
    firewall-cmd --permanent --zone=public --add-masquerade
fi


#---------------------------------------

# Enable HTTPS on public zone

if (( $FWD_HTTPS_PUBLIC )) ; then
    echo_info "Enabling HTTPS on the public zone"
    firewall-cmd --zone=public --add-service=https
    firewall-cmd --permanent --zone=public --add-service=https
fi


#---------------------------------------

echo_info 'Reloading firewalld'

firewall-cmd --reload


#---------------------------------------

# Store a bit of configuration in the environment file

#echo "TRIX_IF_PUBLIC=\"$(firewall-cmd --zone=public --list-interfaces)\"" >> /etc/trinity.sh
#echo "TRIX_IF_TRUSTED=\"$(firewall-cmd --zone=trusted --list-interfaces)\"" >> /etc/trinity.sh

