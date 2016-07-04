#!/bin/bash

# Enable the NFS server and export the HOME directory

OPTS="${NFS_HOME_OPTS:-rw,no_subtree_check,async}"

echo_info 'Adding the /home export'

append_line "/home (${OPTS})" /etc/exports


if [[ "$NFS_HOME_RPCCOUNT" ]] ; then
    echo_info 'Adjusting the number of threads for the NFS server'
    sed -i 's/[# ]*\(RPCNFSDCOUNT=\).*/\1'"${NFS_HOME_RPCCOUNT}"'/g' /etc/sysconfig/nfs
fi


echo_info 'Enabling and starting the NFS server'

systemctl enable nfs-server
systemctl restart nfs-server

