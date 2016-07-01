#!/bin/bash

source /tmp/trinity.sh
source "$POST_COMMON"

# Enable the NFS server and export the shared directory

echo '*** Adding the shared export:'

append_line "${TRIX_ROOT}/shared (ro,no_root_squash)" /etc/exports

echo '*** Enabling and starting the NFS server'

systemctl enable nfs-server
systemctl restart nfs-server

