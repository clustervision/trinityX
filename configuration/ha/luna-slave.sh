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

echo_info "Disable SELinux."

sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0

echo_info "Unpack luna."

pushd /
[ -d /luna ] || git clone https://github.com/clustervision/luna
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

echo_info "Setup DNS."

/usr/bin/cat >>/etc/named.conf <<EOF
include "/etc/named.luna.zones"; 
EOF

echo_info "Create ssh keys."

[ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''

echo_info "Setup nginx."

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

echo_info "Copy systemd unit files."

[ -f /etc/systemd/system/lweb.service ]  || cp -pr ${POST_FILEDIR}/lweb.service /etc/systemd/system/lweb.service
[ -f /etc/systemd/system/ltorrent.service ]  || cp -pr ${POST_FILEDIR}/ltorrent.service /etc/systemd/system/ltorrent.service

echo_info "Reload systemd config."

systemctl daemon-reload


for service in  xinetd nginx; do
    systemctl enable $service
    systemctl start $service
done
