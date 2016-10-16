#!/bin/bash

######################################################################
# Trinity X
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


set -e

function replace_template {
    [ $# -gt 3 -o $# -lt 2 ] && echo "Wrong numger of argument in replace_template." && exit 1
    if [ $# -eq 3 ]; then
        FROM=${1}
        TO=${2}
        FILE=${3}
    fi
    if [ $# -eq 2 ]; then
        FROM=${1}
        TO=${!FROM}
        FILE=${2}
    fi
    sed -i -e "s/{{ ${FROM} }}/${TO//\//\\/}/g" $FILE
}

echo_info "Check if config variables are available."

echo "DRBD_DEVICE=${DRBD_DEVICE:?"Should be defined"}"
echo "DRBD_LOCAL_IP=${DRBD_LOCAL_IP:?"Should be defined"}"
DRBD_LOCAL_HOSTNAME=$(hostname)
echo "DRBD_PARTNER_IP=${DRBD_PARTNER_IP:?"Should be defined"}"
echo "DRBD_PATH_TO_MOUNT=${DRBD_PATH_TO_MOUNT:?"Should be defined"}"

echo_info "Check access to remote node."

DRBD_PARTNER_HOSTNAME=`/usr/bin/ssh ${DRBD_PARTNER_IP} hostname || (echo_error "Unable to connect to ${DRBD_PARTNER_IP}"; exit 1)`

echo_info "Check if block device is available."

(/usr/bin/ssh ${DRBD_PARTNER_IP} ls ${DRBD_DEVICE} && ls ${DRBD_DEVICE}) || (echo_error "${DRBD_DEVICE} not present on one of the nodes."; exit 2)

echo_info "Configure firewalld."

if /usr/bin/firewall-cmd --state >/dev/null ; then
    /usr/bin/firewall-cmd --permanent --add-port=7789/tcp
    /usr/bin/firewall-cmd --reload
else
    echo_warn "Firewalld is not running. 27017/tcp should be open if you enable it later."
fi

echo_info "Create config."

[ -f /etc/drbd.d/trinity_disk.res ] && ( echo_error "Drdb config /etc/drbd.d/trinity_disk.res exists! Stopping!"; exit 4 )

/usr/bin/cp ${POST_FILEDIR}/global_common.conf /etc/drbd.d/global_common.conf
/usr/bin/cp ${POST_FILEDIR}/trinity_disk.res /etc/drbd.d/trinity_disk.res
for VAR in DRBD_DEVICE DRBD_LOCAL_HOSTNAME DRBD_PARTNER_HOSTNAME DRBD_LOCAL_IP DRBD_PARTNER_IP; do
    replace_template $VAR /etc/drbd.d/trinity_disk.res
done
/usr/bin/scp  /etc/drbd.d/global_common.conf ${DRBD_PARTNER_IP}:/etc/drbd.d/global_common.conf
/usr/bin/scp  /etc/drbd.d/trinity_disk.res ${DRBD_PARTNER_IP}:/etc/drbd.d/trinity_disk.res

echo_info "Create device."

/usr/sbin/drbdadm create-md trinity_disk
/usr/bin/ssh ${DRBD_PARTNER_IP} /usr/sbin/drbdadm create-md trinity_disk

/usr/sbin/drbdadm up trinity_disk
/usr/bin/ssh ${DRBD_PARTNER_IP} /usr/sbin/drbdadm up trinity_disk

/usr/sbin/drbdadm -- --overwrite-data-of-peer primary trinity_disk

echo_info "Start services."

systemctl start drbd
systemctl enable drbd

/usr/bin/ssh ${DRBD_PARTNER_IP} "systemctl start drbd; systemctl enable drbd"

#while [ "x$(/usr/sbin/drbdadm dstate trinity_disk)" != "xUpToDate/UpToDate" ]; do
#    echo_info "Waiting for UpToDate/UpToDate"
#    sleep 3
#done

echo_info "Format /dev/drbd/by-res/trinity_disk"

#/usr/sbin/mkfs.ext4 -m 0 /dev/drbd/by-res/trinity_disk
/usr/sbin/mkfs.xfs /dev/drbd/by-res/trinity_disk

[ -d ${DRBD_PATH_TO_MOUNT}.bkp ] && (echo_error "${DRBD_PATH_TO_MOUNT}.bkp exists. Can not proceed.")
[ -d ${DRBD_PATH_TO_MOUNT} ] && /usr/bin/mv ${DRBD_PATH_TO_MOUNT}{,.bkp}

echo_info "mount /dev/drbd/by-res/trinity_disk as ${DRBD_PATH_TO_MOUNT}"

mkdir ${DRBD_PATH_TO_MOUNT}
/usr/bin/mount /dev/drbd/by-res/trinity_disk ${DRBD_PATH_TO_MOUNT}

echo_info "Restore data."

pushd ${DRBD_PATH_TO_MOUNT}.bkp
/usr/bin/tar -cf - . | (cd ${DRBD_PATH_TO_MOUNT} && /usr/bin/tar -xf -)
popd
/usr/bin/rm -rf "${DRBD_PATH_TO_MOUNT}.bkp"

echo_info "Add pacemaker config."

TMPFILE=$(/usr/bin/mktemp -p /root pacemaker.XXXXXXXXX)
/usr/bin/chmod 600 ${TMPFILE}
/usr/sbin/pcs cluster cib ${TMPFILE}

/usr/sbin/pcs -f ${TMPFILE} \
    resource create DRBD ocf:linbit:drbd drbd_resource=trinity_disk
/usr/sbin/pcs -f ${TMPFILE} \
    resource master DRBD
/usr/sbin/pcs -f ${TMPFILE} \
    resource meta DRBD-master \
    master-max="1" \
    master-node-max="1" \
    clone-max="2" \
    clone-node-max="1" \
    notify="true"
/usr/sbin/pcs -f ${TMPFILE} \
    resource create fs_trinity ocf:heartbeat:Filesystem \
    device="/dev/drbd/by-res/trinity_disk" \
    directory="/trinity" \
    fstype="xfs" \
    op monitor interval="61s"
/usr/sbin/pcs -f ${TMPFILE} \
    constraint colocation add fs_trinity with DRBD-master INFINITY with-rsc-role=Master
/usr/sbin/pcs -f ${TMPFILE} \
    constraint colocation add master DRBD-master with ClusterIP
/usr/sbin/pcs -f ${TMPFILE} \
    constraint order promote DRBD-master then start fs_trinity

/usr/sbin/pcs cluster cib-push ${TMPFILE}
