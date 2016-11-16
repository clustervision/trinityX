
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


# Fetch all the config that will be required to do the initial HA setup of the
# secondary controller.

# This is essentially a workaround to the fact that until we have Corosync and
# Pacemaker up and running on the inactive controller, the Pacemaker-managed NFS
# mount of the active controller export isn't available, and we can't copy data
# from it. But we need the Corosync authentication key to start Pacemaker NFS
# mount resource, which we can't copy yet, so we're stuck in a catch-22.
# The same goes for the SSH keys, which would have allowed us to scp the files.

# The solution is:
# - prepare all the config files that the secondary install will need in a
#   subdirectory of the main NFS export;
# - immediately after detection of the secondary install, mount the main NFS
#   export by hand and rsync that subdirectory to the secondary FS root (this
#   post script).


display_var HA PRIMARY_INSTALL CTRL{,1}_IP STDCFG_TRIX_ROOT


#---------------------------------------
# Non-HA
#---------------------------------------

if flag_is_unset HA ; then
    echo_info 'No HA required, exiting.'
    exit
fi


#---------------------------------------
# HA primary
#---------------------------------------

if flag_is_set PRIMARY_INSTALL ; then
    
    echo_info 'Setting up the base files for the primary install'
    
    rm -f /etc/trinity.local.shadow
    rm -fr /root/secondary
    
    install -m 600 /dev/null /etc/trinity.local.shadow
    
    mkdir /root/secondary
    chmod 700 /root/secondary
    cp "$POST_FILEDIR"/README.txt /root/secondary

    exit
fi


#---------------------------------------
# HA secondary
#---------------------------------------

# Create the directory for the essential data that will be picked up by the
# secondary installation

mkdir -p /root/secondary
chmod 700 /root/secondary


# We have to mount the NFS from the primary controller to get the data we need.
# We'll try the floating IP first. If it doesn't work we'll try direct. If it
# still doesn't work, life is tough.

mntdir=$(mktemp -d)

echo_info 'Mounting the primary NFS export'

if mount -v -t nfs ${CTRL_IP}:"${STDCFG_TRIX_ROOT:-/trinity}" "$mntdir" || \
   mount -v -t nfs ${CTRL1_IP}:"${STDCFG_TRIX_ROOT:-/trinity}" "$mntdir" ; then
    
    echo_info 'Copying secondary data from primary mount'
    rsync -ra "${mntdir}/secondary/" /root/secondary/
    umount "$mntdir"
    rm -fr "$mntdir"

else
    echo_error 'Error mounting the primary NFS export, exiting.'
    rm -fr "$mntdir"
    exit 1
fi

