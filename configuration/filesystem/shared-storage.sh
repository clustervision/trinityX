
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


display_var HA PRIMARY_INSTALL TRIX_CTRL{1,2}_{IP,HOSTNAME} TRIX_ROOT \
           SHARED_FS_{TYPE,DEVICE,DRBD_WAIT_FOR_SYNC,NO_FORMAT,FORMAT_OPTIONS} \
            SHARED_FS_CTRL{1,2}_IP


#---------------------------------------
# Shared functions
#---------------------------------------

function check_block_device {

    if [[ -b "$1" ]] ; then
        dev=$1

    elif [[ -b "/dev/$1" ]] ; then
        dev=/dev/$1

    else
        echo_error "Invalid backend block device: ${1:-(empty)}"
        exit 1
    fi

    if grep "^${dev}[0-9]* " /proc/mounts ; then
        echo_error 'THE BLOCK DEVICE (OR ONE OF ITS PARTITIONS) IS MOUNTED! Exiting now.'
        exit 1
    fi

    echo $dev
}



function partition_device {

    echo_info "Partitioning the block device: $1"

    # zap GPT + MBR
    if ! sgdisk -Z $1 2>/dev/null ; then
        echo_error 'Failed to zap the partition tables of the device, exiting.'
        exit 1
    fi

    # create a new GPT + one partition taking up all the space
    if ! sgdisk -n 1:0:0 -c 1:TrinityX_shared $1 ; then
        echo_error 'Failed to create a new partition on the device, exiting.'
        exit 1
    fi

    if flag_is_unset QUIET ; then
        echo
        sgdisk -p $1
        echo
    fi
}



function format_device {

    echo_info "Formatting the block device: $1"

    if ! mkfs.xfs -f -b size=4096 -s size=4096 $SHARED_FS_FORMAT_OPTIONS $1 ; then
        echo_error 'Failed to format the device, exiting.'
        exit 1
    fi
}



function install_drbd_config {

    echo_info 'Installing the DRBD configuration files'

    install -D -b "${POST_FILEDIR}"/global_common.conf /etc/drbd.d/global_common.conf
    render_template "${POST_FILEDIR}"/trinity_disk.res > /etc/drbd.d/trinity_disk.res
}



function start_drbd {

    echo_info 'Starting DRBD'

    if ! systemctl restart drbd ; then
        echo_error 'Failed to start the DRBD service, check the logs.'
        exit 1
    fi
}



function stop_drbd {

    echo_info 'Stopping DRBD'

    if ! systemctl stop drbd ; then
        echo_error 'Failed to stop the DRBD service, check the logs.'
        exit 1
    fi
}



function create_drbd_metadata {

    echo_info 'Creating the DRBD metadata on the device'

    if ! drbdadm -- --force create-md trinity_disk ; then
        echo_error 'Failed to create DRBD metadata, exiting.'
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
        flag_is_set PRIMARY_INSTALL && {
            pcs resource delete trinity-fs
            pcs resource delete trinity-drbd
        }
        mv -b /etc/drbd.d/trinity_disk.res /etc/drbd.d/trinity_disk.res.bak
        umount -f "${TRIX_ROOT}"
        drbdadm down trinity_disk
        systemctl stop drbd

    else
        echo_info 'Storing configuration details'

        for i in SHARED_FS_{TYPE,DEVICE,PART,DRBD_DEVICE} ; do
            store_variable /etc/trinity.sh $i "${!i}"
        done
    fi
}


trap victor_nettoyeur EXIT



#---------------------------------------
# Configuration checks
#---------------------------------------

# As we installed DRBD in all cases, we need to disable the usage count
install -D -b "${POST_FILEDIR}"/global_common.conf.nocount /etc/drbd.d/global_common.conf


if flag_is_unset SHARED_FS_TYPE ; then
    if flag_is_unset HA ; then
        SHARED_FS_TYPE=export
    else
        echo_error 'No shared storage configuration selected, exiting.'
        exit 1
    fi
fi

if flag_is_unset HA && [[ "$SHARED_FS_TYPE" == drbd ]] ; then
    # the only value unavailable to non-HA setups
    echo_error 'DRBD use case unavailable in non-HA setups, exiting.'
    exit 1
fi


case $SHARED_FS_TYPE in

    drbd | dev )
            echo_info "Use case \"$SHARED_FS_TYPE\" selected, setting up the device and FS."
            ;;

    none | export )
            echo_info "Use case \"$SHARED_FS_TYPE\" selected. No FS setup required, exiting."
            exit 0
            ;;

    * )     echo_error 'Invalid shared storage use case, exiting.'
            exit 1

esac



################################################################################
#                                                                              #
# From that point onward we're only dealing with 'drbd' and 'dev' use cases.   #
#                                                                              #
################################################################################


#---------------------------------------
# Use case: "drbd"
#---------------------------------------


if [[ $SHARED_FS_TYPE == drbd ]] ; then
    
    # Prepare the device

    SHARED_FS_DEVICE=$(check_block_device "$SHARED_FS_DEVICE")
    SHARED_FS_DRBD_DEVICE=/dev/drbd1
    display_var SHARED_FS_{,DRBD_}DEVICE

    if flag_is_unset SHARED_FS_NO_FORMAT ; then
        sgdisk -Z ${SHARED_FS_DEVICE} 2>/dev/null
        # some strange timing issues now and then, so:
        sleep 2 ; sync
    fi

    # Set up DRBD and check that it's good

    install_drbd_config
    flag_is_unset SHARED_FS_NO_FORMAT && create_drbd_metadata


    #---------------------------------------
    # HA primary
    #---------------------------------------

    if flag_is_set PRIMARY_INSTALL ; then

        # Set up the local resource and filesystem

        start_drbd

        echo_info 'Setting DRBD resource as primary'
        if ! drbdadm -- --overwrite-data-of-peer primary trinity_disk ; then
            echo_error 'Failed to set DRBD resource as primary, exiting.'
            exit 1
        fi

        # Alright now we can format the thing
        flag_is_unset SHARED_FS_NO_FORMAT && format_device /dev/drbd/by-res/trinity_disk

        flag_is_unset QUIET && { echo ; cat /proc/drbd ; echo ; }

        # It will be started again later by the pacemaker resource
        stop_drbd


        # Set up the Pacemaker resources

        echo_info 'Setting up the Pacemaker resources'

        tmpfile=$(mktemp -p /root pacemaker_drbd.XXXX)
        pcs cluster cib $tmpfile

        # The pair of resources for the DRBD service
        pcs -f $tmpfile resource create DRBD ocf:linbit:drbd drbd_resource=trinity_disk op monitor interval=59s
        pcs -f $tmpfile resource master Trinity-drbd DRBD master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true

        # The filesystem on top
        pcs -f $tmpfile resource create trinity-fs ocf:heartbeat:Filesystem \
            device=/dev/drbd/by-res/trinity_disk directory="$TRIX_ROOT" fstype=xfs \
            options="nodiscard,inode64" run_fsck=force force_unmount=safe \
            op monitor interval=31s

        # More advanced check at a longer interval
        pcs -f $tmpfile resource op add trinity-fs monitor interval=67s OCF_CHECK_LEVEL=10

        # The colocation rules
        pcs -f $tmpfile constraint order set Trinity-drbd Trinity Trinity-secondary
        pcs -f $tmpfile constraint colocation add Trinity with Trinity-drbd score=INFINITY with-rsc-role=Master
        pcs -f $tmpfile resource group add Trinity trinity-fs --after trinity-ip

        # Apply the changes
        if ! pcs cluster cib-push $tmpfile ; then
            echo_error 'Failed to push the new resource configuration to Pacemaker, exiting.'
            exit 1
        fi

        # Give it time to digest the new info
        sleep 5s

        # And then DRBD might start a tiny bit too slow for Pacemaker's taste,
        # and the trinity-fs resource fails. So clean it up and start again.
        pcs resource cleanup trinity-fs


    #---------------------------------------
    # HA secondary
    #---------------------------------------

    else

        # Because Pacemaker will have tried to start the slave resource before
        # the config is ready, it failed. So let's clear up and wait for it to
        # start again.

        echo_info 'Restarting the slave DRBD resource'

        if ! pcs resource cleanup DRBD ; then
            echo_error 'Failed to cleanup the status of the DRBD resource, exiting.'
            exit 1
        fi

        # Aaaaand let it breathe.
        sleep 5s


        if flag_is_set SHARED_FS_DRBD_WAIT_FOR_SYNC ; then

            echo_info 'Waiting for the full synchronization of the secondary disk.
           Monitor the progress with: watch -n 5 cat /proc/drbd'

            minor=$(drbdsetup show trinity_disk | awk -F '[ \t;]+' '/device.*minor/ {print $4}')

            if ! drbdsetup wait-sync $minor ; then
                echo_error 'Failed to wait for full synchronization, exiting.'
                exit 1
            fi
        fi
    fi




#---------------------------------------
# Use case: "dev"
#---------------------------------------

else

    # Step 1: prepare the device
    # -------

    # Shared device, visible on both controllers
    SHARED_FS_DEVICE=$(check_block_device "$SHARED_FS_DEVICE")
    SHARED_FS_PART=${SHARED_FS_DEVICE}1
    display_var SHARED_FS_{DEVICE,PART}

    if flag_is_unset HA || flag_is_set PRIMARY_INSTALL ; then
        partition_device $SHARED_FS_DEVICE
        format_device $SHARED_FS_PART
    fi


    # Step 2: set up the mount / Pacemaker resource
    # -------

    if flag_is_unset HA ; then

        echo_info 'Setting up the mount'

        render_template "${POST_FILEDIR}"/nonHA_fstab >> /etc/fstab
        if ! mount "${TRIX_ROOT}" ; then
            echo_error 'Failed to mount the device, exiting.'
            exit 1
        fi

    elif flag_is_set PRIMARY_INSTALL ; then

        echo_info 'Setting up the Pacemaker resource'

        tmpfile=$(mktemp -p /root pacemaker_dev.XXXX)
        pcs cluster cib $tmpfile

        # The filesystem
        pcs -f $tmpfile resource create trinity-fs ocf:heartbeat:Filesystem \
            device="$SHARED_FS_PART" directory="$TRIX_ROOT" fstype=xfs \
            options="nodiscard,inode64" run_fsck=force force_unmount=safe \
            op monitor interval=31s

        # More advanced check at a longer interval
        pcs -f $tmpfile resource op add trinity-fs monitor interval=67s OCF_CHECK_LEVEL=10

        # The colocation rules
        pcs -f $tmpfile resource group add Trinity trinity-fs --after trinity-ip

        # Apply the changes
        if ! pcs cluster cib-push $tmpfile ; then
            echo_error 'Failed to push the new resource configuration to Pacemaker, exiting.'
            exit 1
        fi
    fi
fi

