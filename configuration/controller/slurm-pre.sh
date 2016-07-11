#!/bin/bash
set -e

source /etc/trinity.sh

echo_info "Creating Slurm and Munge users"

useradd munge -U
useradd slurm -U

store_variable "${TRIX_ROOT}/trinity.sh" MUNGE_USER_ID $(id -u munge)
store_variable "${TRIX_ROOT}/trinity.sh" SLURM_USER_ID $(id -u slurm)

mkdir -p /var/log/slurm
chown slurm:slurm /var/log/slurm
chmod 750 /var/log/slurm

