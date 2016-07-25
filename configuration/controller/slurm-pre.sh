#!/bin/bash
set -e

source /etc/trinity.sh

echo_info "Creating Slurm and Munge users"

if [ "x${MUNGE_GROUP_ID}" = "x" ]; then 
    groupadd -r munge
    store_variable "${TRIX_SHFILE}" MUNGE_GROUP_ID $(getent group | awk -F\: '$1=="munge"{print $3}')
fi
if [ "x${MUNGE_USER_ID}" = "x" ]; then 
    useradd -r -g munge -d /var/run/munge -s /sbin/nologin munge
    store_variable "${TRIX_SHFILE}" MUNGE_USER_ID $(id -u munge)
fi
if [ "x${SLURM_GROUP_ID}" = "x" ]; then 
    groupadd -r slurm
    store_variable "${TRIX_SHFILE}" SLURM_GROUP_ID $(getent group | awk -F\: '$1=="slurm"{print $3}')
fi
if [ "x${SLURM_USER_ID}" = "x" ]; then
    useradd -r -g slurm -d /var/log/slurm  -s /sbin/nologin slurm
    store_variable "${TRIX_SHFILE}" SLURM_USER_ID $(id -u slurm)
fi

mkdir -p /var/log/slurm
chown slurm:slurm /var/log/slurm
chmod 750 /var/log/slurm

