#!/bin/bash
set -e

display_var MUNGE_{GROUP,USER}_ID SLURM_{GROUP,USER}_ID

echo_info "Creating Slurm and Munge users"

groupadd -r ${MUNGE_GROUP_ID:+"-g $MUNGE_GROUP_ID"} munge 
store_variable "${TRIX_SHFILE}" MUNGE_GROUP_ID $(getent group | awk -F\: '$1=="munge"{print $3}')

useradd -r ${MUNGE_USER_ID:+"-u $MUNGE_USER_ID"} -g munge -d /var/run/munge -s /sbin/nologin munge
store_variable "${TRIX_SHFILE}" MUNGE_USER_ID $(id -u munge)

groupadd -r ${SLURM_GROUP_ID:+"-g $SLURM_GROUP_ID"} slurm
store_variable "${TRIX_SHFILE}" SLURM_GROUP_ID $(getent group | awk -F\: '$1=="slurm"{print $3}')

useradd -r ${SLURM_USER_ID:+"-u $SLURM_USER_ID"} -g slurm -d /var/log/slurm  -s /sbin/nologin slurm
store_variable "${TRIX_SHFILE}" SLURM_USER_ID $(id -u slurm)

mkdir -p /var/log/slurm
chown slurm:slurm /var/log/slurm
chmod 750 /var/log/slurm

