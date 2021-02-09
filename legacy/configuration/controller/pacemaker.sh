
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

display_var HA PRIMARY_INSTALL TRIX_CTRL{1,2}_{HOSTNAME,IP} \
            COROSYNC_CTRL{1,2}_IP PACEMAKER_HACLUSTER_PW



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
    sleep 5s

    until corosync-cfgtool -s ; do
        echo 'Waiting for Corosync to come up...'
        sleep 5s
    done
}


function pacemaker_hacluster_pw_auth {

    echo_info 'Starting the Pacemaker daemon'
    systemctl start pcsd

    echo "$PACEMAKER_HACLUSTER_PW" | passwd --stdin hacluster

    if (( $? )) ; then
        echo_error 'Failed to set the password for the "hacluster" user, exiting.'
        exit 1
    fi

    # When someone runs 'auth' from controller1 and controller2 in unavailable it will not
    # be possible to run pcsd-related commands from first controller
    # As this controller is not authorized to run commands on controller2
    # See secondary section.

    echo_info 'Authenticating the "hacluster" user'
    pcs cluster auth -u hacluster -p "${PACEMAKER_HACLUSTER_PW}" --all
}


function pacemaker_start_and_check {

    echo_info 'Starting the cluster'
    pcs cluster start
    sleep 5s

    until pcs status ; do
        echo 'Waiting for the cluster to come up...'
        sleep 5s
    done

    systemctl enable pcsd
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

COROSYNC_CTRL1=${COROSYNC_CTRL1_IP-$TRIX_CTRL1_HOSTNAME}
COROSYNC_CTRL2=${COROSYNC_CTRL2_IP-$TRIX_CTRL2_HOSTNAME}

if flag_is_set PRIMARY_INSTALL ; then
    COROSYNC_TOTEM_NETWORK=${COROSYNC_CTRL1_IP-$TRIX_CTRL1_IP}
else
    COROSYNC_TOTEM_NETWORK=${COROSYNC_CTRL2_IP-$TRIX_CTRL2_IP}
fi



#---------------------------------------
# HA, primary
#---------------------------------------

if flag_is_set PRIMARY_INSTALL ; then

    if flag_is_unset PACEMAKER_KEEP_CLUSTER ; then
        echo_info 'Destroying pre-existing cluster configuration'
        pcs cluster destroy
    fi


    # --- Corosync ---

    corosync_config_file

    echo_info "Setting up Corosync's authentication key"
    [[ -e /etc/corosync/authkey ]] || corosync-keygen -l
    cp -a /etc/corosync/authkey /root/secondary/corosync.authkey

    corosync_start_and_check


    # -- Pacemaker ---

    echo_info 'Setting the password for the "hacluster" user'
    if ! declare PACEMAKER_HACLUSTER_PW="$(get_password "$PACEMAKER_HACLUSTER_PW")" ; then
        echo_warn 'Reusing a read-only password, probably from a previous installation.'
        display_var PACEMAKER_HACLUSTER_PW
    fi

    pacemaker_hacluster_pw_auth
    pacemaker_start_and_check

    # We need to store that password in the local shadow file, as well as in a
    # file for the secondary to pick up.
    store_password PACEMAKER_HACLUSTER_PW "$PACEMAKER_HACLUSTER_PW"


    echo_info 'Configuring the cluster'
    pcs property set stonith-enabled=false
    pcs property set no-quorum-policy=ignore
    pcs resource defaults migration-threshold=1


    echo_info 'Creating the Trinity groups and floating IP address resource'

    tmpfile=$(mktemp -p /root pacemaker.XXXX)
    pcs cluster cib $tmpfile

    # Primary core resources
    pcs -f $tmpfile resource create primary ocf:heartbeat:Dummy op monitor interval=179s
    pcs -f $tmpfile resource create trinity-ip ocf:heartbeat:IPaddr2 ip=${TRIX_CTRL_IP} op monitor interval=29s
    pcs -f $tmpfile resource group add Trinity primary trinity-ip

    # Secondary core resources
    pcs -f $tmpfile resource create secondary ocf:heartbeat:Dummy op monitor interval=181s
    pcs -f $tmpfile resource group add Trinity-secondary secondary

    # Trinity group first, then Trinity-secondary
    pcs -f $tmpfile constraint order set Trinity Trinity-secondary
    # Decide where to run Trinity first, then look for another machine for Trinity-secondary
    pcs -f $tmpfile constraint colocation add Trinity-secondary with Trinity score=-INFINITY

    if ! pcs cluster cib-push $tmpfile ; then
        echo_error 'Failed to push the new resource configuration to Pacemaker, exiting.'
        exit 1
    fi

    check_cluster trinity-ip

    # Cosmetics

    /usr/bin/cp "${POST_FILEDIR}"/pcs-status.sh  /etc/profile.d/



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

    #
    # We need to run pcs cluster auth from every member of the cluster when ALL members are available
    #
    /usr/bin/ssh $COROSYNC_CTRL1 /usr/sbin/pcs cluster auth -u hacluster -p "${PACEMAKER_HACLUSTER_PW}" --all

    pacemaker_start_and_check

    check_cluster secondary

    # Cosmetics

    /usr/bin/cp "${POST_FILEDIR}"/pcs-status.sh  /etc/profile.d/


fi

