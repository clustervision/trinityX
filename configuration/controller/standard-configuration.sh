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


# TrinityX
# Standard controller post-installation script
# This should include all the most common tasks that have to be performed after
# a completely standard CentOS minimal installation.

# Configuration variables are sourced by the configuration script, and are made
# available in the shell environment.

# Fallback values for configuration parameters

TRIX_ROOT="${STDCFG_TRIX_ROOT:-/trinity}"
TRIX_VERSION="${STDCFG_TRIX_VERSION:-unknown}"
SSHROOT="${STDCFG_SSHROOT:-0}"

# All the paths and locations

TRIX_HOME="${TRIX_HOME:-${TRIX_ROOT}/home}"
TRIX_IMAGES="${TRIX_IMAGES:-${TRIX_ROOT}/images}"
TRIX_LOCAL="${TRIX_LOCAL:-${TRIX_ROOT}/local}"
TRIX_LOCAL_APPS="${TRIX_LOCAL}/applications"
TRIX_LOCAL_MODFILES="${TRIX_LOCAL}/modulefiles"
TRIX_SHARED="${TRIX_SHARED:-${TRIX_ROOT}/shared}"
TRIX_SHARED_TMP="${TRIX_SHARED}/tmp"
TRIX_SHARED_APPS="${TRIX_SHARED}/applications"
TRIX_SHARED_MODFILES="${TRIX_SHARED}/modulefiles"

TRIX_SHADOW="${TRIX_ROOT}/trinity.shadow"
TRIX_SHFILE="${TRIX_SHARED}/trinity.sh"
TRIX_LOCAL_SHFILE="/etc/trinity.local.sh"


#---------------------------------------

echo_info "Creating Trinity directory tree"

for i in TRIX_{HOME,IMAGES,LOCAL,LOCAL_APPS,LOCAL_MODFILES} \
         TRIX_{SHARED,SHARED_TMP,SHARED_APPS,SHARED_MODFILES} ; do
    mkdir -p "${!i}"
done


#---------------------------------------

echo_info "Creating the Trinity shell environment file"

cat > "$TRIX_SHFILE" << EOF
# TrinityX environment file
# Do not modify!

TRIX_VERSION="$TRIX_VERSION"
TRIX_ROOT="$TRIX_ROOT"

TRIX_HOME="${TRIX_HOME}"
TRIX_IMAGES="${TRIX_IMAGES}"
TRIX_LOCAL="${TRIX_LOCAL}"
TRIX_LOCAL_APPS="${TRIX_LOCAL_APPS}"
TRIX_LOCAL_MODFILES="${TRIX_LOCAL_MODFILES}"
TRIX_SHARED="${TRIX_SHARED}"
TRIX_SHARED_TMP="${TRIX_SHARED_TMP}"
TRIX_SHARED_APPS="${TRIX_SHARED_APPS}"
TRIX_SHARED_MODFILES="${TRIX_SHARED_MODFILES}"

TRIX_SHADOW="${TRIX_SHADOW}"
TRIX_SHFILE="${TRIX_SHFILE}"
TRIX_LOCAL_SHFILE="${TRIX_LOCAL_SHFILE}"

EOF

cat >> "$TRIX_SHFILE" << 'EOF' 
if [[ "$BASH_SOURCE" == "$0" ]] ; then
	echo "$TRIX_VERSION"
fi

EOF

chmod 600 "$TRIX_SHFILE"
ln -f -s "$TRIX_SHFILE" /etc/trinity.sh


#---------------------------------------

echo_info "Creating the Trinity local shell environment file"

# It may already contain stuff (PRIMARY_INSTALL for example), so we don't
# overwrite it entirely.

{
    echo '# TrinityX local environment file'
    cat "$TRIX_LOCAL_SHFILE"
} | sponge "$TRIX_LOCAL_SHFILE"

chmod 600 "$TRIX_LOCAL_SHFILE"


#---------------------------------------

echo_info "Creating the Trinity private file"

cat > "$TRIX_SHADOW" << EOF
# TrinityX shadow file
EOF

chmod 600 "$TRIX_SHADOW"


#---------------------------------------

if (( $SSHROOT )) ; then
    echo_info "Allowing SSH login as root"
    
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    systemctl restart sshd
else
    echo_info "SSH login as root disabled"
fi


#---------------------------------------

echo_info "Generating the root's private SSH keys"

[[ -e /root/.ssh/id_rsa ]] || \
    ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
[[ -e /root/.ssh/id_ecdsa ]] || \
    ssh-keygen -t ecdsa -b 521 -N "" -f /root/.ssh/id_ecdsa
[[ -e /root/.ssh/id_ed25519 ]] || \
    ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519


echo_info 'Copying the SSH info to the shared directory'

mkdir -p "${TRIX_ROOT}/root"
cp -a /root/.ssh "${TRIX_ROOT}/root"


#---------------------------------------

echo_info "Disabling SELinux"

sed -i 's/\(^SELINUX=\).*/\1disabled/g' /etc/sysconfig/selinux /etc/selinux/config
setenforce 0
echo_warn "Please remember to reboot the node after completing the configuration!"

