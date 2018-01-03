
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


display_var HA PRIMARY_INSTALL TRIX_{ROOT,LOCAL,IMAGES,SHARED,HOME} \
            SHARED_FS_TYPE NFS_EXPORT_{LOCAL,IMAGES,SHARED,HOME} \
            NFS_{RPCCOUNT,ENABLE_RDMA}



#---------------------------------------
# Shared functions
#---------------------------------------

# Syntax: exports_setup <template> <destination>

function setup_exports {

    echo_info 'Setting up the NFS exports'

    mkdir -p "$(dirname "$2")"
    render_template "$1" | column -t -s '|' > "$2"
}



function setup_sysconfig {

    # RH7 uses a weird configuration system for NFS. At boot the
    # nfs-config.service unit file processes /etc/sysconfig/nfs and writes the
    # results in /run/sysconfig/nfs-utils, which is used by the NFS server.
    # I'm not really sure about the logic behind it. What it means for us though
    # is that we have to restart that service after updating the config file.

    render_template "${POST_FILEDIR}"/sysconfig_nfs > /etc/sysconfig/nfs
    sync

    if ! systemctl restart nfs-config ; then
        echo_error 'Failed to restart the nfs-config service, exiting.'
        exit 1
    fi
}



function symlink_exports {

    mkdir -p /etc/exports.d
    ln -f -s "${TRIX_LOCAL}"/etc/exports.d/trinity.exports /etc/exports.d/trinity.exports
}



function start_nfs_server {

    echo_info 'Starting the NFS server'

    if ! ( systemctl restart nfs-server && \
           systemctl enable nfs-server ) ; then
        echo_error 'Failed to start the NFS server, exiting'
        exit 1
    fi
}



function stop_nfs_server {

    echo_info 'Stopping the NFS server'

    if ! ( systemctl stop nfs-server && \
           systemctl disable nfs-server ) ; then
        echo_error 'Failed to stop the NFS server, exiting'
        exit 1
    fi
}



#---------------------------------------
# Exit hook
#---------------------------------------

function victor_nettoyeur {

    if (( $? )) ; then
        echo_warn 'Victor, nettoyeur.'

        # just brute-forcing our way through all the cases
        flag_is_set PRIMARY_INSTALL && pcs resource delete trinity-nfs-server
        pcs resource delete trinity-nfs-client-local
        pcs resource delete trinity-nfs-client-images
        pcs resource delete trinity-nfs-client-shared
        pcs resource delete trinity-nfs-client-home
        systemctl stop nfs-server
        systemctl disable nfs-server

    else
        echo_info 'Storing configuration details'

        for i in NFS_EXPORT_{LOCAL,IMAGES,SHARED,HOME} NFS_ENABLE_RDMA ; do
            store_variable /etc/trinity.sh "$i" "${!i:-0}"
        done
    fi
}


trap victor_nettoyeur EXIT



#---------------------------------------
# Configuration checks
#---------------------------------------

# Make sure that we have the base directories, regardless of the FS type

mkdir -p $TRIX_{HOME,IMAGES,LOCAL,SHARED}


# We're assuming that the SHARED_FS_* checks have already been done in the
# shared-storage PS, and that the values that we're picking up from trinity.sh
# are sane...

if flag_is_unset HA ; then
    echo_info 'Non-HA setup, disabling NFS_EXPORT_LOCAL and NFS_EXPORT_IMAGES'
    read NFS_EXPORT_{LOCAL,IMAGES} <<< "0 0"
fi


case $SHARED_FS_TYPE in

    none )
        echo_info '"None" use case selected, not setting up the NFS server.'
        read NFS_EXPORT_{LOCAL,IMAGES,SHARED,HOME} <<< "0 0 0 0"
        exit 0
        ;;

    export | dev | drbd )
        NFS_EXPORT_LOCAL=${NFS_EXPORT_LOCAL:-1}
        NFS_EXPORT_IMAGES=${NFS_EXPORT_IMAGES:-1}
        NFS_EXPORT_SHARED=${NFS_EXPORT_SHARED:-1}
        NFS_EXPORT_HOME=${NFS_EXPORT_HOME:-1}
        ;;

    * ) # We should never get there
        echo_error 'Invalid shared storage use case, exiting.'
        exit 1
esac


flag_is_set NFS_ENABLE_RDMA && proto=rdma || proto=tcp



#---------------------------------------
# Non-HA
#---------------------------------------

if flag_is_unset HA ; then

    setup_exports "${POST_FILEDIR}"/nonHA_exports /etc/exports.d/trinity.exports
    setup_sysconfig
    start_nfs_server
    showmount -e



#---------------------------------------
# HA primary
#---------------------------------------

elif flag_is_set PRIMARY_INSTALL ; then

    setup_exports "${POST_FILEDIR}"/HA_exports "${TRIX_LOCAL}"/etc/exports.d/trinity.exports
    symlink_exports
    render_template "${POST_FILEDIR}"/nfsmount.conf > /etc/nfsmount.conf
    setup_sysconfig

    # Information that should survive a failover
    mkdir -p "${TRIX_LOCAL}"/var/lib/nfs


    # Let's see if the config flies
    start_nfs_server
    showmount -e
    stop_nfs_server


    echo_info 'Setting up the NFS server Pacemaker resource'

    tmpfile=$(mktemp -p /root pacemaker_nfs.XXXX)
    pcs cluster cib $tmpfile

    pcs -f $tmpfile resource create trinity-nfs-server ocf:heartbeat:nfsserver \
        nfs_shared_infodir="${TRIX_LOCAL}"/var/lib/nfs op monitor interval=47s

    pcs -f $tmpfile resource group add Trinity-fs trinity-nfs-server --after fs-ready

    # Apply the changes
    if ! pcs cluster cib-push $tmpfile ; then
        echo_error 'Failed to push the new resource configuration to Pacemaker, exiting.'
        exit 1
    fi

    check_cluster trinity-nfs-server trinity-ip


    # The resources for the NFS mounts are disabled for now, as we need the
    # default configuration on the secondary controller before starting them.
    # Then they will be enabled.

    echo_info 'Setting up the Pacemaker NFS mounts'

    tmpfile=$(mktemp -p /root pacemaker_nfs-clients.XXXX)
    pcs cluster cib $tmpfile

    if flag_is_set NFS_EXPORT_LOCAL ; then

        pcs -f $tmpfile resource create trinity-nfs-client-local \
            ocf:heartbeat:Filesystem fstype=nfs \
            device="$TRIX_CTRL_HOSTNAME:$TRIX_LOCAL" directory="$TRIX_LOCAL" \
            fast_stop=no force_unmount=safe op monitor interval=83s \
            --group Trinity-secondary

        pcs -f $tmpfile resource disable trinity-nfs-client-local
    fi

    if flag_is_set NFS_EXPORT_IMAGES ; then

        pcs -f $tmpfile resource create trinity-nfs-client-images \
            ocf:heartbeat:Filesystem fstype=nfs \
            device="$TRIX_CTRL_HOSTNAME:$TRIX_IMAGES" directory="$TRIX_IMAGES" \
            fast_stop=no force_unmount=safe op monitor interval=89s \
            --group Trinity-secondary

        pcs -f $tmpfile resource disable trinity-nfs-client-images
    fi

    if flag_is_set NFS_EXPORT_SHARED ; then

        pcs -f $tmpfile resource create trinity-nfs-client-shared \
            ocf:heartbeat:Filesystem fstype=nfs \
            device="$TRIX_CTRL_HOSTNAME:$TRIX_SHARED" directory="$TRIX_SHARED" \
            fast_stop=no force_unmount=safe op monitor interval=79s \
            --group Trinity-secondary

        pcs -f $tmpfile resource disable trinity-nfs-client-shared
    fi

    if flag_is_set NFS_EXPORT_HOME ; then

        pcs -f $tmpfile resource create trinity-nfs-client-home \
            ocf:heartbeat:Filesystem fstype=nfs \
            device="$TRIX_CTRL_HOSTNAME:$TRIX_HOME" directory="$TRIX_HOME" \
            fast_stop=no force_unmount=safe op monitor interval=71s \
            --group Trinity-secondary

        pcs -f $tmpfile resource disable trinity-nfs-client-home
    fi

    # Apply the changes
    if ! pcs cluster cib-push $tmpfile ; then
        echo_error 'Failed to push the new resource configuration to Pacemaker, exiting.'
        exit 1
    fi



#---------------------------------------
# HA secondary
#---------------------------------------

else

    symlink_exports
    render_template "${POST_FILEDIR}"/nfsmount.conf > /etc/nfsmount.conf
    setup_sysconfig


    echo_info 'Enabling the Pacemaker NFS mounts'

    tmpfile=$(mktemp -p /root pacemaker_nfs-clients.XXXX)
    pcs cluster cib $tmpfile

    if flag_is_set NFS_EXPORT_LOCAL ; then
        pcs -f $tmpfile resource enable trinity-nfs-client-local
    fi

    if flag_is_set NFS_EXPORT_IMAGES ; then
        pcs -f $tmpfile resource enable trinity-nfs-client-images
    fi

    if flag_is_set NFS_EXPORT_SHARED ; then
        pcs -f $tmpfile resource enable trinity-nfs-client-shared
    fi

    if flag_is_set NFS_EXPORT_HOME ; then
        pcs -f $tmpfile resource enable trinity-nfs-client-home
    fi

    # Apply the changes
    if ! pcs cluster cib-push $tmpfile ; then
        echo_error 'Failed to push the new resource configuration to Pacemaker, exiting.'
        exit 1
    fi
fi

