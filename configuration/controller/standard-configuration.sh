#!/bin/bash

# trinityX
# Standard controller post-installation script
# This should include all the most common tasks that have to be performed after
# a completely standard CentOS minimal installation.

# Configuration variables are sourced by the configuration script, and are made
# available in the shell environment.

source "$POST_CONFIG"


# Fallback values for configuration parameters

TRIX_ROOT="${STDCFG_TRIX_ROOT:-/trix}"
TRIX_VERSION="${STDCFG_TRIX_VERSION:-unknown}"
SSHROOT="${STDCFG_SSHROOT:-0}"

# All the paths and locations

TRIX_HOME="${TRIX_ROOT}/home"
TRIX_IMAGES="${TRIX_ROOT}/images"
TRIX_SHARED="${TRIX_ROOT}/shared"
TRIX_APPS="${TRIX_ROOT}/shared/applications"

TRIX_SHADOW="${TRIX_ROOT}/trinity.shadow"
TRIX_SHFILE="${TRIX_SHARED}/trinity.sh"


#---------------------------------------

echo_info "Creating Trinity directory tree"

mkdir -p "$TRIX_ROOT"
mkdir -p "$TRIX_HOME"
mkdir -p "$TRIX_IMAGES"
mkdir -p "$TRIX_SHARED"
mkdir -p "$TRIX_APPS"


#---------------------------------------

echo_info "Creating the Trinity shell environment file"

cat > "$TRIX_SHFILE" << EOF
# TrinityX environment file
# Please do not modify!

TRIX_VERSION="$TRIX_VERSION"

TRIX_ROOT="$TRIX_ROOT"
TRIX_HOME="$TRIX_HOME"
TRIX_IMAGES="$TRIX_IMAGES"
TRIX_SHARED="$TRIX_SHARED"
TRIX_APPS="$TRIX_APPS"

TRIX_SHFILE="$TRIX_SHFILE"
TRIX_SHADOW="$TRIX_SHADOW"

EOF

cat >> "$TRIX_SHFILE" << 'EOF' 
if [[ "$BASH_SOURCE" == "$0" ]] ; then
	echo "$TRIX_VERSION"
fi

EOF

chmod 644 "$TRIX_SHFILE"
ln -f -s "$TRIX_SHFILE" /etc/trinity.sh


#---------------------------------------

echo_info "Creating the Trinity private file"

cat > "$TRIX_SHADOW" << EOF
# Trinity shadow file
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

echo_info "Generating root's private SSH keys if required"

[[ -e /root/.ssh/id_rsa ]] || ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
[[ -e /root/.ssh/id_ed25519 ]] || ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519


#---------------------------------------

echo_info "Disabling SELinux"

sed -i 's/\(^SELINUX=\).*/\1disabled/g' /etc/sysconfig/selinux /etc/selinux/config
setenforce 0
echo_warn "Please remember to reboot the node after completing the configuration!"


#---------------------------------------

echo_info 'Moving the user homes to the shared folder'

store_system_variable /etc/default/useradd HOME "$TRIX_HOME"

