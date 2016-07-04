#!/bin/bash

source /etc/trinity.sh

# Enable the NFS server and export the shared directory

OPTS="${NFS_SHARED_OPTS:-ro,no_root_squash}"

echo_info 'Adding the shared export'

append_line "${TRIX_ROOT}/shared (${OPTS})" /etc/exports


echo_info 'Enabling and starting the NFS server'

systemctl enable nfs-server
systemctl restart nfs-server

