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
TRIX_VERSION="${STDCFG_TRIX_VERSION:-10}"
SSHROOT="${STDCFG_SSHROOT:-0}"


#---------------------------------------

echo_info "Creating Trinity directory tree"

mkdir -pv "$TRIX_ROOT"
mkdir -pv "${TRIX_ROOT}/shared"
mkdir -pv "${TRIX_ROOT}/applications"


#---------------------------------------

echo_info "Creating the Trinity shell environment file"

cat > "${TRIX_ROOT}/trinity.sh" << EOF
# trinityX environment file
# Please do not modify!

TRIX_VERSION="$TRIX_VERSION"
TRIX_ROOT="$TRIX_ROOT"
TRIX_CTRL_HOSTNAME=$(hostname)

EOF

cat >> "${TRIX_ROOT}/trinity.sh" << 'EOF' 
if [[ "$BASH_SOURCE" == "$0" ]] ; then
	echo "$TRIX_VERSION"
fi

EOF

chmod 640 "${TRIX_ROOT}/trinity.sh"
ln -f -s "${TRIX_ROOT}/trinity.sh" /etc/trinity.sh


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
echo_warn "Please remember to reboot the node after completing the configuration!"

