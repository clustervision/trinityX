#!/bin/bash

source /etc/trinity.sh
source "$POST_CONFIG"


# Enable the NFS server and exports

SHARED_OPTS="${NFS_SHARED_OPTS:-ro,no_root_squash}"


echo_info 'Adding the shared export'

append_line "${TRIX_SHARED} (${SHARED_OPTS})" /etc/exports


if [[ "$NFS_HOME_OPTS" ]] ; then
    echo_info 'Adding the /home export'
    append_line "${TRIX_HOME} (${NFS_HOME_OPTS})" /etc/exports
    store_variable /etc/trinity.sh HOME_ON_NFS 1
fi


if [[ "$NFS_HOME_RPCCOUNT" ]] ; then
    echo_info 'Adjusting the number of threads for the NFS server'
    sed -i 's/[# ]*\(RPCNFSDCOUNT=\).*/\1'"${NFS_HOME_RPCCOUNT}"'/g' /etc/sysconfig/nfs
fi


echo_info 'Enabling and starting the NFS server'

systemctl enable nfs-server
systemctl restart nfs-server

