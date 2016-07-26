#!/bin/bash
set -e

source "$POST_CONFIG"
source /etc/trinity.sh
source "$TRIX_SHADOW"

echo "CTRL_IP=${CTRL_IP:?"Should be defined"}"
CTRL_HOSTNAME=$(/usr/bin/hostname -s)
CTRL_HOSTNAME_FULL=$(/usr/bin/hostname)
echo "CTRL1_HOSTNAME_FULL=${CTRL1_HOSTNAME_FULL:?"Should be defined"}"
CTRL1_HOSTNAME=${CTRL1_HOSTNAME_FULL%%.*}
echo "CTRL1_IP=${CTRL1_IP:?"Should be defined"}"
echo "CTRL2_IP=${CTRL2_IP:?"Should be defined"}"

eval $(/usr/bin/ipcalc -np $(/usr/sbin/ip a show to  ${CTRL_IP} | /usr/bin/awk 'NR==2{print $2}') | /usr/bin/awk '{print "CTRL_IP_"$0}')
echo "CTRL_IP_NETWORK=${CTRL_IP_NETWORK:?"Unable to find"}"
echo "CTRL_IP_PREFIX=${CTRL_IP_PREFIX:?"Unable to find"}"

echo_info "Check if remote host is available."

CTRL2_HOSTNAME=`/usr/bin/ssh ${CTRL2_IP} hostname -s || (echo_error "Unable to connect to ${CTRL2_IP}"; exit 1)`
CTRL2_HOSTNAME_FULL=`/usr/bin/ssh ${CTRL2_IP} hostname || (echo_error "Unable to connect to ${CTRL2_IP}"; exit 1)`

echo_info "Add records to /etc/hosts"

cat <<EOF >>/etc/hosts
# --- Trinity HA config controller-master.sh ---
${CTRL_IP}      ${CTRL_HOSTNAME} ${CTRL_HOSTNAME_FULL}
${CTRL1_IP}     ${CTRL1_HOSTNAME} ${CTRL1_HOSTNAME_FULL}
${CTRL2_IP}     ${CTRL2_HOSTNAME} ${CTRL2_HOSTNAME_FULL}
EOF

echo_info "Copy /etc/hosts to ${CTRL2_IP}"

/usr/bin/scp /etc/hosts ${CTRL2_IP}:/etc/hosts

echo_info "Find out which interface owns ${CTRL_IP}"

TMPVAR=$(/usr/sbin/ip a show to ${CTRL_IP} | awk 'NR==1{print $2}')
CTRL1_IF=${TMPVAR%:}
echo "${CTRL1_IF:?"Error in finding interface."}"

echo_info "Reconfigure interface ifcfg-${CTRL1_IF}"

/usr/bin/sed -i -e "s/IPADDR=${CTRL_IP}/IPADDR=${CTRL1_IP}/" /etc/sysconfig/network-scripts/ifcfg-${CTRL1_IF}

echo_info "Reset interface"

/usr/sbin/ifdown ${CTRL1_IF}
/usr/sbin/ifup ${CTRL1_IF}

echo_info "Assign alias"

/usr/sbin/ip a add ${CTRL_IP}/${CTRL_IP_PREFIX} dev ${CTRL1_IF}

echo_info "Change hostname from ${CTRL_HOSTNAME} to ${CTRL1_HOSTNAME}"

/usr/bin/hostnamectl set-hostname ${CTRL1_HOSTNAME_FULL}
