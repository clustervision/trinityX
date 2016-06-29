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
	echo -e "\n################################################################################"
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

sed -i 's/\(^SELINUX=\).*/\1disabled/g' /etc/sysconfig/selinux
echo "Please remember to reboot the node after completing the configuration!"

#---------------------------------------

myecho "Copying packages and setting up the local repository"

# INFO: we don't update the packages right now as some sites will have special
# network access rules. We only do enough to be able to fetch the specific RPMs
# that we need for other post scripts.
# Updating the whole system and adding other repositories is for later.

cp -rv "${MYPATH}/../packages" "${TRIX_ROOT}"

cat > /etc/yum.repos.d/trix-local.repo << EOF
[trix-local]
name=trinityX - local repository
baseurl=file://${TRIX_ROOT}/packages/
enabled=1
gpgcheck=0
EOF

