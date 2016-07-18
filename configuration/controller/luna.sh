#!/bin/bash
set -e

source "$POST_CONFIG"
source /etc/trinity.sh

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

echo_info "Check config variables available."

echo "LUNA_FRONTEND=${LUNA_FRONTEND?"Should be defined"}"
echo "LUNA_NETWORK=${LUNA_NETWORK?"Should be defined"}"
echo "LUNA_NETWORK_NAME=${LUNA_NETWORK_NAME:-cluster}"
echo "LUNA_PREFIX=${LUNA_PREFIX?"Should be defined"}"

LUNA_NETMASK=`ipcalc -s -m ${LUNA_NETWORK}/${LUNA_PREFIX} | sed 's/.*=//'`
echo "LUNA_NETMASK=${LUNA_NETMASK?"Cannot compute netmask"}"
echo "LUNA_DHCP_RANGE_START=${LUNA_DHCP_RANGE_START?"Should be defined"}"
echo "LUNA_DHCP_RANGE_END=${LUNA_DHCP_RANGE_END?"Should be defined"}"

_LUNA_MONGO_ROOT_PASS=`get_password $LUNA_MONGO_ROOT_PASS`
store_password LUNA_MONGO_ROOT_PASS $_LUNA_MONGO_ROOT_PASS
_LUNA_MONGO_PASS=`get_password $LUNA_MONGO_PASS`
store_password LUNA_MONGO_PASS $_LUNA_MONGO_PASS

echo "LUNA_MONGO_ROOT_PASS=${_LUNA_MONGO_ROOT_PASS?"Should be defined"}"
echo "LUNA_MONGO_PASS=${_LUNA_MONGO_PASS?"Should be defined"}"


echo_info "Disable SELinux."

sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0

echo_info "Unpack luna."

pushd /
[ -d /luna ] || tar -xzvf ${POST_FILEDIR}/luna-*.tgz
popd


echo_info "Add users and create folders."

id luna >/dev/null 2>&1 || useradd -d /opt/luna luna
chown luna: /opt/luna
chmod ag+rx /opt/luna
mkdir -p /var/log/luna
chown luna: /var/log/luna
mkdir -p /opt/luna/{boot,torrents}
chown luna: /opt/luna/{boot,torrents}

echo_info "Create symlinks."

pushd /usr/lib64/python2.7
ln -fs ../../../luna/src/module luna
popd
pushd /usr/sbin
ln -fs ../../luna/src/exec/luna
ln -fs ../../luna/src/exec/lpower
ln -fs ../../luna/src/exec/lweb
ln -fs ../../luna/src/exec/ltorrent
ln -fs ../../luna/src/exec/lchroot
popd
pushd /opt/luna
ln -fs ../../luna/src/templates/
popd

echo_info "Setup tftp."

mkdir -p /tftpboot
sed -e 's/^\(\W\+disable\W\+\=\W\)yes/\1no/g' -i /etc/xinetd.d/tftp
sed -e 's|^\(\W\+server_args\W\+\=\W-s\W\)/var/lib/tftpboot|\1/tftpboot|g' -i /etc/xinetd.d/tftp
[ -f /tftpboot/luna_undionly.kpxe ] || cp /usr/share/ipxe/undionly.kpxe /tftpboot/luna_undionly.kpxe

echo_info "Create ssh keys."

[ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''


if [ ! -f /etc/nginx/conf.d/nginx-luna.conf ]; then
    # copy config files
    mv /etc/nginx/nginx.conf{,.bkp_luna}
    cp ${POST_FILEDIR}/nginx.conf /etc/nginx/
    mkdir -p /etc/nginx/conf.d/
    cp ${POST_FILEDIR}/nginx-luna.conf /etc/nginx/conf.d/
fi

echo_info "Start mongo."

systemctl start mongod
systemctl enable mongod

echo_info "Configure mongo auth."


#sed -i -e "s/^[# \t]\+replSet.*/replSet = luna/" /etc/mongod.conf
#systemctl restart mongod
#do_mongo_req "rs.initiate();"
systemctl restart mongod
/usr/bin/mongo << EOF
use admin
db.createUser({user: 'root', pwd: '${_LUNA_MONGO_ROOT_PASS}', roles: [ { role: 'root', db: 'admin' } ]})
EOF
cat > ~/.mongorc.js <<EOF
db.getSiblingDB("admin").auth("root", "${_LUNA_MONGO_ROOT_PASS}")
EOF
sed -i -e "s/^[# \t]\+auth.*/auth = true/" /etc/mongod.conf
systemctl restart mongod
/usr/bin/mongo << EOF
use luna
db.createUser({user: "luna", pwd: "${_LUNA_MONGO_PASS}", roles: [{role: "dbOwner", db: "luna"}]})
EOF
cat << EOF > /etc/luna.conf
[MongoDB]
replicaset=luna
server=localhost
authdb=luna
user=luna
password=${_LUNA_MONGO_PASS}
EOF
chown luna:luna /etc/luna.conf
chmod 600 /etc/luna.conf

echo_info "Copy systemd unit files."

[ -f /etc/systemd/system/lweb.service ]  || cp -pr ${POST_FILEDIR}/lweb.service /etc/systemd/system/lweb.service
[ -f /etc/systemd/system/ltorrent.service ]  || cp -pr ${POST_FILEDIR}/ltorrent.service /etc/systemd/system/ltorrent.service

echo_info "Reload systemd config."

systemctl daemon-reload

/usr/sbin/luna cluster init
/usr/sbin/luna cluster change --frontend_address ${LUNA_FRONTEND}
/usr/sbin/luna network add -n ${LUNA_NETWORK_NAME} -N ${LUNA_NETWORK} -P ${LUNA_PREFIX}
/usr/sbin/luna cluster makedhcp -N ${LUNA_NETWORK_NAME} -s ${LUNA_DHCP_RANGE_START} -e ${LUNA_DHCP_RANGE_END}

for service in  xinetd nginx dhcpd lweb ltorrent; do
    systemctl enable $service
    systemctl start $service
done
