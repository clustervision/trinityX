#!/bin/bash

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


set -e

echo "NFS_HA_MOUNTPOINT=${NFS_HA_MOUNTPOINT:?"Should be defined"}"
echo "NFS_SHARED_INFODIR=${NFS_SHARED_INFODIR:?"Should be defined"}"
echo "NFS_PARTNER_HOST=${NFS_PARTNER_HOST:?"Should be defined"}"
echo "NFS_FLOATING_IP=${NFS_FLOATING_IP:?"Should be defined"}"

NFS_SHARED_INFODIR_PATH="${NFS_HA_MOUNTPOINT}/${NFS_SHARED_INFODIR##*$NFS_HA_MOUNTPOINT/}"

echo_info "Check if pacemaker configured already."

/usr/sbin/pcs resource show NFS >/dev/null  2>&1 && (echo_error "NFS already configured in pacemaker"; exit 2)

echo_info "Check if remote host is available."

NFS_PARTNER_HOSTNAME=`/usr/bin/ssh ${NFS_PARTNER_HOST} /usr/bin/hostname -s || (echo_error "Unable to connect to ${NFS_PARTNER_HOST}"; exit 1)`

echo_info "Create nfsinfo dir."

/usr/bin/mkdir -p ${NFS_SHARED_INFODIR_PATH}

echo_info "Export pacemaker config."

TMPFILE=$(/usr/bin/mktemp -p /root pacemaker.XXXXXXXXX)
/usr/bin/chmod 600 ${TMPFILE}
/usr/sbin/pcs cluster cib ${TMPFILE}

echo_info "Add nfs daemon to pacemaker config."

/usr/sbin/pcs -f ${TMPFILE} \
    resource create nfs-daemon ocf:cv:nfsserver \
    nfs_shared_infodir=${NFS_SHARED_INFODIR_PATH} \
    nfs_no_notify=true \
    nfs_ip=${NFS_FLOATING_IP} \
    nfsd_nproc=64 \
    --group NFS

echo_info "Parse exports."

FSID=0
[ -f /etc/exports.d/* ] && EXPORTSD="/etc/exports.d/*"
cat /etc/exports ${EXPORTSD} | sed -e '/^[#\t ]/d' | \
    while read EPATH ECLIENT EREST; do \
        EOPTS_CL=${ECLIENT%%(*}
        EOPTS_CL=${EOPTS_CL:-0.0.0.0/0}
        #EIP=${EOPTS_CL%%/*}
        #TMPVAR=$(ipcalc -m ${EOPTS_CL})
        #EMASK=${TMPVAR##*=}
        EOPTS=$(echo ${ECLIENT} | sed 's/.*(\(.*\))/\1/')
        RES_NAME=${EPATH//\//}
        /usr/sbin/pcs -f ${TMPFILE} \
            resource create ${RES_NAME} \
            ocf:heartbeat:exportfs \
            directory=$EPATH \
            clientspec=${EOPTS_CL} \
            options=${EOPTS} \
            fsid=${FSID} \
            --group NFS
        FSID=$((${FSID}+1))
    done

echo_info "Add nfsnotify server to pacemaker config."

/usr/sbin/pcs -f ${TMPFILE} \
    resource create nfsnotify \
    ocf:heartbeat:nfsnotify \
    source_host=${NFS_FLOATING_IP} \
    --group NFS

echo_info "Add constraints to pacemaker config."

/usr/sbin/pcs -f ${TMPFILE} constraint colocation add NFS with ClusterIP
/usr/sbin/pcs -f ${TMPFILE} constraint colocation add NFS with fs_trinity
/usr/sbin/pcs -f ${TMPFILE} constraint order start ClusterIP then start NFS
/usr/sbin/pcs -f ${TMPFILE} constraint order start fs_trinity then start NFS

echo_info "Stop systemd services."

/usr/bin/systemctl stop nfs-server.service
/usr/bin/systemctl disable nfs-server.service
/usr/bin/ssh ${NFS_PARTNER_HOST} /usr/bin/systemctl stop nfs-server.service
/usr/bin/ssh ${NFS_PARTNER_HOST} /usr/bin/systemctl disable nfs-server.service

echo_info "Copy NFS config."

/usr/bin/scp /etc/sysconfig/nfs ${NFS_PARTNER_HOST}:/etc/sysconfig/nfs
/usr/bin/scp /etc/exports ${NFS_PARTNER_HOST}:/etc/exports
/usr/bin/scp -pr /etc/exports.d ${NFS_PARTNER_HOST}:/etc/

echo_info "Import pacemaker config."

/usr/sbin/pcs cluster cib-push ${TMPFILE}
