#!/bin/bash

source "$POST_COMMON"

# Enable the NFS server and export the HOME directory

echo '*** Adding the /home export:'

append_line "/home (rw,no_subtree_check,async)" /etc/exports

echo '*** Adjusting the number of threads for the NFS server:'

sed -i 's/[# ]*\(RPCNFSDCOUNT=\).*/\1256/g' /etc/sysconfig/nfs

echo '*** Enabling and starting the NFS server'

systemctl enable nfs-server
systemctl restart nfs-server

