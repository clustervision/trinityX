#!/bin/bash

# trinityX
# Standard controller post-installation script
# This should include all the most common tasks that have to be performed after
# a completely standard CentOS minimal installation.


################################################################################
## Set those environment variables to match your configuration
## Note that the root path must be a full path!

TRIX_VERSION=10
TRIX_ROOT="/trinity"


################################################################################
## Let's go

# A bit ugly, but errors in the output are identified much more quickly:
function myecho {
	echo
	echo "####  $@"
	echo
}

# Set up a few environment variables that we will need later
MYFNAME="$(readlink -f "$0")"
MYPATH="$(dirname "$MYFNAME")"

#---------------------------------------

myecho "Creating Trinity directory tree"

mkdir -pv "$TRIX_ROOT"
mkdir -pv "${TRIX_ROOT}/shared"


#---------------------------------------

myecho "Creating the Trinity shell environment file"

cat > "${TRIX_ROOT}/trinity.sh" << EOF
# trinityX version file
# Please do not modify!

TRIX_VERSION="$TRIX_VERSION"
TRIX_ROOT="$TRIX_ROOT"

EOF

cat >> "${TRIX_ROOT}/trinity.sh" << 'EOF' 
if [[ "$BASH_SOURCE" == "$0" ]] ; then
	echo "$TRIX_VERSION"
fi

EOF

chmod go-w "${TRIX_ROOT}/trinity.sh"
ln -f -s "${TRIX_ROOT}/trinity.sh" /etc/trinity.sh

#---------------------------------------

myecho "Allowing SSH login as root"

sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
systemctl restart sshd

#---------------------------------------

myecho "Generating root's private SSH keys"

[[ -e /root/.ssh/id_rsa ]] || ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
[[ -e /root/.ssh/id_ed25519 ]] || ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519

#---------------------------------------

myecho "Disabling SELinux"

sed -i 's/\(^SELINUX=\).*/\1disabled/g' /etc/sysconfig/selinux /etc/selinux/config
echo "Please remember to reboot the node after completing the configuration!"

