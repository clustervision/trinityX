#!/bin/bash
set -e

source "$POST_CONFIG"
source /etc/trinity.sh
source "$TRIX_SHADOW"

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
    sed -i -e "s/{{ ${FROM} }}/${TO}/g" $FILE
}

echo "PACEMAKER_MASTER_HOST=${PACEMAKER_MASTER_HOST:?"Should be defined"}"
echo "PACEMAKER_SLAVE_HOST=${PACEMAKER_SLAVE_HOST:?"Should be defined"}"
echo "PACEMAKER_FLOATING_HOST=${PACEMAKER_FLOATING_HOST:?"Should be defined"}"
PACEMAKER_MASTER_HOST_IP=$(/usr/bin/getent ahosts ${PACEMAKER_MASTER_HOST} | /usr/bin/awk 'NR==1{print $1}')
ipcalc -np $(ip a show to  ${PACEMAKER_MASTER_HOST_IP} | awk 'NR==2{print $2}') | awk '{print "PACEMAKER_MASTER_HOST_IP_"$0}' | eval
PACEMAKER_NETWORK=${PACEMAKER_MASTER_HOST_IP_NETWORK}
PACEMAKER_PREFIX=${PACEMAKER_MASTER_HOST_IP_PREFIX}
echo 
if [ ! "${PACEMAKER_PASS}" ]; then
    PACEMAKER_PASS=`get_password $PACEMAKER_PASS`
    store_password PACEMAKER_PASS ${PACEMAKER_PASS}
fi

echo_info "Check if remote host is available."

PACEMAKER_SLAVE_HOSTNAME=`/usr/bin/ssh ${PACEMAKER_SLAVE_HOST} hostname || (echo_error "Unable to connect to ${PACEMAKER_SLAVE_HOST}"; exit 1)`

echo_info "Create corosync.conf."

[ -f /etc/corosync/corosync.conf ] && (echo_error "/etc/corosync/corosync.conf already exists on this node. Exiting.;" exit 2)

/usr/bin/cp ${POST_FILEDIR}/templ_corosync.conf /etc/corosync/corosync.conf
for VAR in PACEMAKER_NETWORK PACEMAKER_MASTER_HOST PACEMAKER_SLAVE_HOST; do
    replace_template $VAR /etc/corosync/corosync.conf
done

/usr/bin/scp /etc/corosync/corosync.conf ${PACEMAKER_SLAVE_HOST}:/etc/corosync/corosync.conf

echo_info "Configure firewalld"

/usr/bin/firewall-cmd --permanent --add-service=high-availability
/usr/bin/firewall-cmd --reload

/usr/bin/ssh ${PACEMAKER_SLAVE_HOST} "/usr/bin/firewall-cmd --permanent --add-service=high-availability"
/usr/bin/ssh ${PACEMAKER_SLAVE_HOST} "/usr/bin/firewall-cmd --reload"

echo_info "Start pcsd"

systemctl start pcsd.service
systemctl enable pcsd.service
/usr/bin/ssh ${PACEMAKER_SLAVE_HOST} "systemctl start pcsd.service"
/usr/bin/ssh ${PACEMAKER_SLAVE_HOST} "systemctl enable pcsd.service"

echo_info "Setup hacluster password."

echo ${PACEMAKER_PASS} | passwd --stdin hacluster
/usr/bin/ssh ${PACEMAKER_SLAVE_HOST} "echo ${PACEMAKER_PASS} | passwd --stdin hacluster"


echo_info "Authenticate cluster."

/usr/sbin/pcs cluster auth ${PACEMAKER_MASTER_HOST} ${PACEMAKER_SLAVE_HOST} -u hacluster -p ${PACEMAKER_PASS}

echo_info "Initialize cluster."

/usr/sbin/pcs cluster start --all

echo_warn "Disable STONITH. Please do not confider it as a production use case."

/usr/sbin/pcs property set stonith-enabled=false

echo_info "Add floating ip."

/usr/sbin/pcs resource create ClusterIP ocf:heartbeat:IPaddr2 \
    ip=${PACEMAKER_FLOATING_HOST} cidr_netmask=${PACEMAKER_PREFIX} op monitor interval=30s
