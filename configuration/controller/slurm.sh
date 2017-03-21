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



if [ "x${SLURMDBD_MYSQL_PASS}" = "x" ]; then
    SLURMDBD_MYSQL_PASS=`get_password $SLURMDBD_MYSQL_PASS`
    store_password SLURMDBD_MYSQL_PASS $SLURMDBD_MYSQL_PASS
fi



function replace_template() {
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

function make_bkp() {
    FILE=$1
    SUFFIX="trixbkp.$(/usr/bin/date +%Y-%m-%d_%H-%M-%S)"
    if [ ! -e "${FILE}" ]; then
        echo_warn "Unable to find ${FILE}"
        return 0
    fi
    echo_info "Create backup of $FILE to ${FILE}.${SUFFIX}"
    RES=$(/usr/bin/cp -prf "${FILE}" "${FILE}.${SUFFIX}"; echo $?)
    return $RES

}

function move_etc_slurm() {
    echo_info "Creating ${TRIX_ROOT}/shared/etc"
    mkdir -p ${TRIX_ROOT}/shared/etc
    echo_info "Moving /etc/slurm to ${TRIX_ROOT}/shared/etc"
    if [ -d ${TRIX_ROOT}/shared/etc/slurm ]; then
        make_bkp ${TRIX_ROOT}/shared/etc/slurm
    fi
    if [ ! -h /etc/slurm ]; then
        /usr/bin/mv /etc/slurm ${TRIX_ROOT}/shared/etc/
        /usr/bin/ln -s ${TRIX_ROOT}/shared/etc/slurm /etc/slurm
    else
        echo_warn "Unable to find /etc/slurm"
    fi
    if [ ! -d ${TRIX_ROOT}/shared/etc/slurm ]; then
        echo_error "Unable to copy /etc/slurm to ${TRIX_ROOT}/shared/etc/slurm"
    fi
    echo_info "Copy slurm config files"

    /usr/bin/cp ${POST_FILEDIR}/slurm*.conf /etc/slurm/
    /usr/bin/cp ${POST_FILEDIR}/{topology,cgroup}.conf /etc/slurm/
    /usr/bin/chmod 640 /etc/slurm/slurmdbd.conf
}

function create_spool_dir() {
    echo_info "Create spool dir"
    /usr/bin/mkdir -p /var/spool/slurm
    /usr/bin/chmod 755 /var/spool/slurm
}

function create_munge_key() {
    echo_info "Creating munge.key in ${TRIX_ROOT}/shared/etc/munge"
    /usr/bin/mkdir -p ${TRIX_ROOT}/shared/etc/munge
    /usr/bin/chmod 700 ${TRIX_ROOT}/shared/etc/munge
    /usr/bin/chown munge:munge ${TRIX_ROOT}/shared/etc/munge
    /usr/bin/dd if=/dev/urandom bs=1 count=1024 of=${TRIX_ROOT}/shared/etc/munge/munge.key
    /usr/bin/chmod 400 ${TRIX_ROOT}/shared/etc/munge/munge.key
    /usr/bin/chown munge:munge ${TRIX_ROOT}/shared/etc/munge/munge.key
}

function tune_systemd_units() {

    echo_info "Update systemd units"
    SYSTEMD_PATH="/etc/systemd/system/"

    mkdir -p ${SYSTEMD_PATH}/munge.service.d
    mkdir -p ${SYSTEMD_PATH}/slurmctld.service.d
    mkdir -p ${SYSTEMD_PATH}/slurmdbd.service.d

    for service in munge slurmctld slurmdbd; do
        cat << EOF > ${SYSTEMD_PATH}/${service}.service.d/remote-fs.conf
[Unit]
After=remote-fs.target
Requires=remote-fs.target
EOF
    done

    cat << EOF > ${SYSTEMD_PATH}/slurmctld.service.d/customexec.conf
[Unit]
Requires=munge.service slurmdbd.service

[Service]
Restart=always
EOF

        cat << EOF > ${SYSTEMD_PATH}/munge.service.d/customexec.conf
[Service]
ExecStart=
ExecStart=/usr/sbin/munged  --key-file ${TRIX_ROOT}/shared/etc/munge/munge.key
Restart=always

EOF
        cat << EOF > ${SYSTEMD_PATH}/slurmdbd.service.d/customexec.conf
[Unit]
Requires=munge.service

[Service]
Restart=always
EOF
        systemctl daemon-reload

}


function configure_slurm() {

    echo_info "Changing variable placeholders."

    replace_template TRIX_CTRL_IP                /etc/slurm/slurm.conf
    replace_template TRIX_CTRL_IP                /etc/slurm/slurmdbd.conf
    replace_template TRIX_CTRL1_HOSTNAME         /etc/slurm/slurmdbd.conf
    replace_template TRIX_CTRL2_HOSTNAME         /etc/slurm/slurmdbd.conf
    replace_template SLURMDBD_MYSQL_PASS    /etc/slurm/slurmdbd.conf
    replace_template SLURMDBD_MYSQL_USER    /etc/slurm/slurmdbd.conf
    replace_template SLURMDBD_MYSQL_DB      /etc/slurm/slurmdbd.conf
}

function move_spool() {
    echo_info "Move spool dir"
    SPOOL_DIR=${TRIX_ROOT}/shared/slurm-spool
    /usr/bin/mkdir -p ${SPOOL_DIR}
    /usr/bin/chmod 750 ${SPOOL_DIR}
    /usr/bin/sed -i -e '/StateSaveLocation/d' /etc/slurm/slurm.conf
    append_line /etc/slurm/slurm.conf "StateSaveLocation=$SPOOL_DIR"
    if [ -f /var/spool/slurm/clustername ]; then
        /usr/bin/mv /var/spool/slurm/* ${SPOOL_DIR} 2>/dev/null || /usr/bin/true
        /usr/bin/rm -rf /var/spool/slurm 2>/dev/null || /usr/bin/true
    fi

}

function do_sql_req {
    if [ -f ~/.my.cnf ]; then
        echo $@ | /usr/bin/mysql
        return 0
    fi
    if [ ${MYSQL_ROOT_PASSWORD} ]; then
        echo $@ | /usr/bin/mysql -u root --password="${MYSQL_ROOT_PASSWORD}"
        return 0
    fi
    echo $@ | /usr/bin/mysql -u root
}

function create_slurmdbd_user() {
    echo_info "Create DB for slurm accounting."
    SUFFIX="trixbkp.$(/usr/bin/date +%Y-%m-%d_%H-%M-%S)"
    /usr/bin/mysqldump -u root --password="${MYSQL_ROOT_PASSWORD}" \
        --databases ${SLURMDBD_MYSQL_DB} >\
        /root/mysqldump.${SLURMDBD_MYSQL_DB}.${SUFFIX} 2>/dev/null || /usr/bin/true
    do_sql_req "DROP DATABASE IF EXISTS ${SLURMDBD_MYSQL_DB};"
    do_sql_req "CREATE DATABASE IF NOT EXISTS ${SLURMDBD_MYSQL_DB};"
    do_sql_req "DROP USER IF EXISTS '${SLURMDBD_MYSQL_USER}'@'localhost';"
    do_sql_req "DROP USER IF EXISTS '${SLURMDBD_MYSQL_USER}'@'%';"
    do_sql_req "CREATE USER '${SLURMDBD_MYSQL_USER}'@'localhost' IDENTIFIED BY '${SLURMDBD_MYSQL_PASS}';"
    do_sql_req "CREATE USER '${SLURMDBD_MYSQL_USER}'@'%' IDENTIFIED BY '${SLURMDBD_MYSQL_PASS}';"
    do_sql_req "GRANT ALL PRIVILEGES ON ${SLURMDBD_MYSQL_DB}.* TO '${SLURMDBD_MYSQL_USER}'@'%';"
    do_sql_req "FLUSH PRIVILEGES;"
}

function create_cluster_in_acc_db() {
    echo_info "Initialize accounting database for the default cluster"
    TRIES=$1
    if [ "x${TRIES}" = "x" ]; then
        TRIES=5
    fi
    while ! /usr/bin/sacctmgr -i add cluster cluster; do
        echo_info "Trying again in 5 sec. (${TRIES})"
        TRIES=$(( ${TRIES}-1 ))
        if [ ${TRIES} -le 0 ]; then
             echo_error "Timeout waiting initialization slurm accounting."
             exit 1
        fi
        sleep 5
    done
}

function configure_pacemaker() {
    echo_info "Configure pacemaker's resources."
    TMPFILE=$(/usr/bin/mktemp -p /root pacemaker_drbd.XXXX)
    /usr/sbin/pcs cluster cib ${TMPFILE}
    /usr/sbin/pcs -f ${TMPFILE} resource delete slurmctld 2>/dev/null || /usr/bin/true
    /usr/sbin/pcs -f ${TMPFILE} resource delete slurmdbd 2>/dev/null || /usr/bin/true
    /usr/sbin/pcs -f ${TMPFILE} resource create slurmdbd systemd:slurmdbd --force --group=Slurm
    /usr/sbin/pcs -f ${TMPFILE} resource create slurmctld systemd:slurmctld --force --group=Slurm
    /usr/sbin/pcs -f ${TMPFILE} constraint colocation add Slurm with Trinity
    /usr/sbin/pcs -f ${TMPFILE} constraint order start trinity-fs then start Slurm
    /usr/sbin/pcs -f ${TMPFILE} constraint order promote Trinity-galera then start Slurm
    /usr/sbin/pcs cluster cib-push ${TMPFILE}
}

function install_basic() {
    move_etc_slurm
    create_munge_key
    create_spool_dir
    tune_systemd_units
    configure_slurm
    create_slurmdbd_user
}

function install_standalone() {
    install_basic
    replace_template HEADNODE "${TRIX_CTRL1_HOSTNAME}" /etc/slurm/slurm.conf
    echo_info "Start services"
    if ! /usr/bin/systemctl start slurmdbd; then
        echo_error "Unable to start slurmdbd"
        exit 1
    fi
    if ! /usr/bin/systemctl start munge slurmctld; then
        echo_error "Unable to start services"
        exit 1
    fi
    /usr/bin/systemctl enable munge slurmctld slurmdbd
    create_cluster_in_acc_db
}

function install_primary() {
    install_basic
    replace_template HEADNODE "${TRIX_CTRL1_HOSTNAME},${TRIX_CTRL2_HOSTNAME}" /etc/slurm/slurm.conf
    /usr/bin/sed -i -e 's/^#\(ControlAddr=.*\)$/\1/' /etc/slurm/slurm.conf
    /usr/bin/sed -i -e 's/^#\(DbdBackupHost=.*\)$/\1/' /etc/slurm/slurmdbd.conf
    /usr/bin/systemctl stop slurmctld slurmdbd
    /usr/bin/systemctl disable slurmctld slurmdbd
    move_spool
    if ! /usr/bin/systemctl start slurmdbd; then
        echo_error "Unable to start slurmdbd"
        exit 1
    fi
    if ! /usr/bin/systemctl start munge slurmctld; then
        echo_error "Unable to start services"
        exit 1
    fi
    create_cluster_in_acc_db
    configure_pacemaker
}

function install_secondary() {
    if [ -h /etc/slurm ]; then
        /usr/bin/rm -rf /etc/slurm
    else
        /usr/bin/mv /etc/slurm{,.orig}
    fi
    /usr/bin/ln -s ${TRIX_ROOT}/shared/etc/slurm /etc/slurm
    tune_systemd_units
}

display_var SLURMDBD_MYSQL_DB SLURMDBD_MYSQL_USER

if flag_is_unset HA; then
    install_standalone
else
    if flag_is_set PRIMARY_INSTALL; then
        install_primary
    else
        install_secondary
    fi
fi
