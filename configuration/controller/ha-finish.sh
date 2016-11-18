
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


# Prepare all the config that will be required to do the initial HA setup of the
# secondary controller.

# This is essentially a workaround to the fact that until we have Corosync and
# Pacemaker up and running on the inactive controller, the Pacemaker-managed NFS
# mount of the active controller export isn't available, and we can't copy data
# from it. But we need the Corosync authentication key to start Pacemaker NFS
# mount resource, which we can't copy yet, so we're stuck in a catch-22.
# The same goes for the SSH keys, which would have allowed us to scp the files.

# The solution is:
# - prepare all the config files that the secondary install will need in a
#   subdirectory of the main NFS export (this post script);
# - immediately after detection of the secondary install, mount the main NFS
#   export by hand and rsync that subdirectory to the secondary FS root.


display_var HA PRIMARY_INSTALL TRIX_{LOCAL,SHADOW}


#---------------------------------------
# Non-HA
#---------------------------------------

# If not HA, nothing to do here, exit now.
flag_is_unset HA && exit


#---------------------------------------
# HA primary
#---------------------------------------

if flag_is_set PRIMARY_INSTALL ; then
    # We need to move the secondary directory over to the NFS server:
    mv /root/secondary "${TRIX_LOCAL}"


#---------------------------------------
# HA secondary
#---------------------------------------

else
    # If we're the secondary install, we only need to remove the temp dir
    # containing the bootstrap data
    rm -fr /root/secondary

fi


# And n both cases, store in trinity.shadow the passwords that were written to
# trinity.local.shadow before the shared directory was up, if any, and delete
# the file.

cat /etc/trinity.local.shadow >> "$TRIX_SHADOW"
rm -f /etc/trinity.local.shadow

