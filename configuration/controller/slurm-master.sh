#!/bin/bash
set -e
source "$POST_CONFIG"
source /etc/trinity.sh
source "$TRIX_SHADOW"

echo_info "Check if variables are defined."

echo "SLURM_CTRL1_HOST=${SLURM_CTRL1_HOST:?"Should be defined"}"
SLURM_CTRL1_HOSTNAME_SHORT=$(/usr/bin/hostname -s)
echo "SLURM_CTRL2_HOST=${SLURM_CTRL2_HOST:?"Should be defined"}"
echo "SLURM_FLOATING_IP=${SLURM_FLOATING_IP:?"Should be defined"}"

echo_info "Check if remote host is available."

SLURM_CTRL2_HOSTNAME_SHORT=`/usr/bin/ssh ${SLURM_CTRL2_HOST} /usr/bin/hostname -s || (echo_error "Unable to connect to ${SLURM_CTRL2_HOST}"; exit 1)`

echo_info "Edit slurm.conf"

/usr/bin/sed -i -e "s/^ControlMachine=.*/ControlMachine=${SLURM_CTRL1_HOSTNAME_SHORT},${SLURM_CTRL2_HOSTNAME_SHORT}/" /etc/slurm/slurm.conf
/usr/bin/grep -q 'ControlAddr=' /etc/slurm.conf || echo "#ControlAddr=" >> /etc/slurm/slurm.conf
/usr/bin/sed -i -e "s/^[#\t ]*ControlAddr=.*/ControlAddr=${SLURM_FLOATING_IP}/" /etc/slurm/slurm.conf

echo_info "Edit slurmdbd.conf"

/usr/bin/sed -i -e "s/^DbdHost=.*/DbdHost=${SLURM_CTRL1_HOSTNAME_SHORT}/" /etc/slurm/slurmdbd.conf
/usr/bin/sed -i -e "s/^[#\t ]*DbdBackupHost=.*/DbdBackupHost=${SLURM_CTRL2_HOSTNAME_SHORT}/" /etc/slurm/slurmdbd.conf

echo_info "Copy systemd unit files to ${SLURM_CTRL2_HOST}"

/usr/bin/scp -pr /etc/systemd/system/{munge*,slurm*} ${SLURM_CTRL2_HOST}:/etc/systemd/system/
/usr/bin/ssh ${SLURM_CTRL2_HOST} /usr/bin/systemctl daemon-reload

echo_info "Add pacemaker config."

TMPFILE=$(/usr/bin/mktemp -p /root pacemaker.XXXXXXXXX)
/usr/bin/chmod 600 ${TMPFILE}
/usr/sbin/pcs cluster cib ${TMPFILE}

/usr/sbin/pcs -f ${TMPFILE} \
    resource create slurmdbd --group Slurm systemd:slurmdbd
/usr/sbin/pcs -f ${TMPFILE} \
    resource create slurm    --group Slurm systemd:slurm --force
/usr/sbin/pcs -f ${TMPFILE} \
    constraint colocation add Slurm with ClusterIP
/usr/sbin/pcs -f ${TMPFILE} \
    constraint colocation add Slurm with fs_trinity
#/usr/sbin/pcs -f ${TMPFILE} \
#    constraint colocation add Slurm with DRBD-master INFINITY with-rsc-role=Master
#/usr/sbin/pcs -f ${TMPFILE} \
#    constraint order promote DRBD-master then start Slurm
/usr/sbin/pcs -f ${TMPFILE} \
    constraint order start fs_trinity then start Slurm
/usr/sbin/pcs -f ${TMPFILE} \
    constraint order start ClusterIP then start Slurm

/usr/sbin/pcs cluster cib-push ${TMPFILE}
