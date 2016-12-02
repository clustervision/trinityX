
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


# Post script to set up Corosync and Pacemaker

display_var HA PRIMARY_INSTALL CTRL{1,2}_{HOSTNAME,IP} COROSYNC_CTRL{1,2}_IP \
            PACEMAKER_HACLUSTER_PW



#---------------------------------------
# Shared functions
#---------------------------------------

function corosync_config_file {
    
    echo_info "Setting up Corosync's configuration file"
    render_template "${POST_FILEDIR}"/templ_corosync.conf > /etc/corosync/corosync.conf
}


function corosync_start_and_check {
    
    echo_info 'Starting Corosync'
    systemctl restart corosync
    
    read -t 5 -p 'Waiting for Corosync to come up...'
    echo
    
    if corosync-cfgtool -s ; then
        echo All good
        # We don't need to enable the corosync unit as it will be started
        # automatically by Pacemaker.
    else
        echo_error 'Corosync failed to start, exiting.'
        exit 1
    fi
}


function pacemaker_hacluster_pw_auth {
    
    echo "$PACEMAKER_HACLUSTER_PW" | passwd --stdin hacluster
    
    if ( ? ) ; then
        echo_error 'Failed to set the password for the "hacluster" user, exiting.'
        exit 1
    fi
    
    # This is expected to produce a half-error during the primary installation, as
    # the secondary node isn't there yet. Which means that we can't use the return
    # code to check if it's done...
    
    echo_info 'Authenticating the "hacluster" user'
    pcs cluster auth -u hacluster -p "$PACEMAKER_HACLUSTER_PW" --all
}


function pacemaker_start_and_check {
    
    echo_info 'Starting the Pacemaker daemon'
    systemctl start pcsd
    
    echo_info 'Starting the cluster'
    pcs cluster start
    
    read -t 5 -p 'Waiting for the cluster to come up...'
    echo
    
    if pcs cluster status ; then
        echo All good
        systemctl enable pcsd
    else
        echo_error 'The Pacemaker cluster failed to start, exiting.'
        exit 1
    fi
}



#---------------------------------------
# Non-HA
#---------------------------------------

if flag_is_unset HA ; then
    
    echo_info 'No HA support was requested, exiting.'
    exit
fi



#---------------------------------------
# Corosync interfaces
#---------------------------------------

# Default values for interfaces to bind to
# We use the hostnames if possible, to make Pacemaker happy. If the user
# specified alternative IPs, then we use IPs and they'll get warnings.

COROSYNC_CTRL1=${COROSYNC_CTRL1_IP-$CTRL1_HOSTNAME}
COROSYNC_CTRL2=${COROSYNC_CTRL2_IP-$CTRL2_HOSTNAME}

if flag_is_set PRIMARY_INSTALL ; then
    COROSYNC_TOTEM_NETWORK=${COROSYNC_CTRL1_IP-$CTRL1_IP}
else
    COROSYNC_TOTEM_NETWORK=${COROSYNC_CTRL2_IP-$CTRL2_IP}
fi



#---------------------------------------
# HA, primary
#---------------------------------------

if flag_is_set PRIMARY_INSTALL ; then
    
    # --- Corosync ---
    
    corosync_config_file
    
    echo_info "Setting up Corosync's authentication key"
    [[ -e /etc/corosync/authkey ]] || corosync-keygen -l
    cp -a /etc/corosync/authkey /root/secondary/corosync.authkey
    
    corosync_start_and_check
    
    # -- Pacemaker ---
    
    echo_info 'Setting the password for the "hacluster" user'
    PACEMAKER_HACLUSTER_PW="$(get_password "$PACEMAKER_HACLUSTER_PW")"
    
    pacemaker_hacluster_pw_auth
    pacemaker_start_and_check
    
    # We need to store that password in the local shadow file, as well as in a
    # file for the secondary to pick up.
    store_password PACEMAKER_HACLUSTER_PW "$PACEMAKER_HACLUSTER_PW"

    echo_info 'Configuring the cluster'
    pcs property set stonith-enabled=false
    pcs property set no-quorum-policy=ignore
    pcs resource defaults migration-threshold=1
    
    #echo_info 'Creating the top-level Trinity resource'
    #pcs resource create Trinity ocf:heartbeat:Dummy
    
    echo_info 'Creating the floating IP address resource'
    pcs resource create ClusterIP ocf:heartbeat:IPaddr2 ip=${CTRL_IP} op monitor interval=29s
    #pcs constraint colocation add ClusterIP with trinity
    #pcs constraint order start trinity then start ClusterIP
    pcs resource group add Trinity ClusterIP


#---------------------------------------
# HA, secondary
#---------------------------------------
    
else
    
    # --- Corosync ---
    
    corosync_config_file
    
    echo_info "Setting up Corosync's authentication key"
    install -D -m 400 --backup /root/secondary/corosync.authkey /etc/corosync/authkey
    
    corosync_start_and_check
    
    # -- Pacemaker ---
    
    echo_info 'Setting the password for the "hacluster" user'
    # The password comes from the shadow file of the primary installation
    pacemaker_hacluster_pw_auth
    pacemaker_start_and_check
fi

