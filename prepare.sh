#!/bin/bash

if [ ! -d /etc/trinity ]; then
    mkdir /etc/trinity
fi

# --------------------------------------------------------------------------------------

function add_message() {
  echo -e "$1" | fold -w70 -s >> /tmp/mesg.$$.dat
}

function show_message() {
  echo "****************************************************************************"
  echo "*                                                                          *"
  while read -r LINE
  do
    printf '*  %-70s  *\n' "$LINE"
  done < /tmp/mesg.$$.dat
  echo "*                                                                          *"
  echo "****************************************************************************"
  truncate -s0 /tmp/mesg.$$.dat
}

function get_confirmation() {
  local DEFAULT=$1
  local MESG=$2
  local CONFIRM=""
  while [ ! "$CONFIRM" ]; do
    case $DEFAULT in
      [Yy]|yes|Yes|YES)
        echo -n "$MESG? (<y>|n): " >&2
        ;;
      *)
        echo -n "$MESG? (y|<n>): " >&2
        ;;
    esac
    read -t 600 CONFIRM
    RET=$?
    if [ "$RET" == "142" ] || [ ! "$CONFIRM" ]; then
      CONFIRM=$DEFAULT
    fi
    case $CONFIRM in
      [Yy]|yes|Yes|YES)
         echo yes
         ;;
      [Nn]|no|No|NO)
         echo no
         ;;
      *)
         CONFIRM=""
         ;;
    esac
  done
}

function store_config() {
  local KEY=$1
  local VALUE=$2
  if [ -f /etc/trinity/prepare.conf ] && [ "$(grep '^'$KEY'=' /etc/trinity/prepare.conf)" ]; then
    sed -i 's/^'$KEY'=.*$/'$KEY'='$VALUE'/' /etc/trinity/prepare.conf
  else
    echo "$KEY=$VALUE" >> /etc/trinity/prepare.conf
  fi
}

# --------------------------------------------------------------------------------------

if [ -f /etc/trinity/prepare.conf ]; then
  while IFS='=' read -ra line; do
    comment=$(echo $line | grep '^#')
    if [ ! "$comment" ]; then
      if [ "$line" ]; then
	key=$(echo ${line[0]})
        value=$(echo ${line[1]})
        declare -x "${key}"="${value}"
        echo "$key = $value"
      fi
    fi
  done < /etc/trinity/prepare.conf
fi

# --------------------------------------------------------------------------------------

if [ ! -f TrinityX.pdf ]; then
  add_message "Please run from within the cloned TrinityX folder"
  show_message
  exit 1
fi

SELINUX=$(getenforce)
if [ "$SELINUX" == "Disabled" ]; then
    add_message "SELinux seems to be disabled on the controller"
    add_message "If you continue, the flag enable_selinux will be set to false"
    add_message "This means you will continue without using SELinux"
    show_message
    if [ ! "$NO_SELINUX" ] && [ ! "$GITLAB_CI" ]; then
      NO_SELINUX=$(get_confirmation n "Do you want to proceed without SELinux")
      store_config 'NO_SELINUX' $NO_SELINUX
    fi
    if [ "$NO_SELINUX" == "no" ]; then
      add_message "Please have a look in /etc/selinux/config, configure SELINUX to permissive, reboot and try the installation again"
      show_message
      exit 1
    fi
    sed -i 's/^enable_selinux:\s\+true/enable_selinux: false/g' site/group_vars/all.yml*
else
  if [ "$SELINUX" == "Permissive" ]; then
    echo "SELinux in permissive state"
  else
    add_message "SELinux is currently not configured in permissive state"
    add_message "TrinityX currently only supports permissive SELinux"
    show_message
    PERM_SELINUX=$(get_confirmation y "Do you want to proceed with permissive SELinux")
    if [ "$PERM_SELINUX" == "no" ] && [ ! "$GITLAB_CI" ]; then
      add_message "Please reconsider having a look in /etc/selinux/config, configure SELINUX to permissive, setenforce 0 and try the installation again"
      show_message
      exit 1
    fi
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
  fi
fi

if [ ! "$GITLAB_CI" ]; then
  if [ ! -f site/tui_configurator ]; then
    if [ ! "$(which wget)" ]; then
      dnf -y install wget
    fi
    ARCH=$(uname -m)
    TRIX_VER=$(grep 'trix_version' site/group_vars/all.yml* 2> /dev/null | grep -oE '[0-9\.]+' | sort -n | tail -n1 | grep -v '' || echo '15')
    wget --directory-prefix site/ https://updates.clustervision.com/trinityx/${TRIX_VER}/install/${ARCH}/tui_configurator
    chmod 755 site/tui_configurator
  fi
fi

# inside a runner (test mode) we do not update the kernel.
if [ "$GITLAB_CI" ]; then
    dnf update -y --exclude=kernel*
else
    dnf update -y
fi
dnf install curl tar git -y

REDHAT_RELEASE=$(grep -i "Red Hat Enterprise Linux" /etc/os-release | grep -oE '[0-9]+' | head -n1)
if [ "$REDHAT_RELEASE" ]; then
  subscription-manager repos --enable codeready-builder-for-rhel-${REDHAT_RELEASE}-x86_64-rpms
  dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${REDHAT_RELEASE}.noarch.rpm -y
  dnf install ansible-core -y
  dnf install ansible -y
else
  dnf install epel-release -y
  dnf install ansible -y 2> /dev/null || dnf install ansible-core -y
  # needed for rocky10
  dnf install ansible-collection-community-general -y 2> /dev/null
  dnf install ansible-collection-ansible-posix -y 2> /dev/null
  ansible-galaxy collection install community.mysql
fi

ansible-galaxy install OndrejHome.pcs-modules-2

# kernel check. Did we pull in a newer kernel?
CURRENT_KERNEL=$(uname -r)
LATEST_KERNEL=$(ls -tr /lib/modules/|tail -n1)

if [ "$USE_CURRENT_KERNEL" != "yes" ] && [ "$CURRENT_KERNEL" != "$LATEST_KERNEL" ] && [ ! "$GITLAB_CI" ]; then
  add_message "Current running kernel is not the latest installed. It comes highly recommended to reboot prior continuing installation."
  add_message "After reboot, please re-run prepare.sh to make sure all requirements are met."
  show_message
  USE_CURRENT_KERNEL=$(get_confirmation n "Do you want to proceed with current kernel")
  if [ "$USE_CURRENT_KERNEL" == "no" ]; then
    exit 1
  fi
fi

if [ ! "$WITH_ZFS" ] && [ ! "$GITLAB_CI" ]; then
  add_message "Would you prefer to include ZFS?" 
  add_message "ZFS is supported in the shared_fs_disk/HA role. If you prefer to use ZFS there, please confirm below."
  show_message
  WITH_ZFS=$(get_confirmation y "Do you want to install ZFS")
fi
store_config 'WITH_ZFS' $WITH_ZFS

if [ "$WITH_ZFS" == "yes" ] || [ "$GITLAB_CI" ]; then
  ARCH=$(uname -m)
  if [ "$ARCH" == "aarch64" ]; then
    add_message "Automated ZFS support for ARM is limited. To have ZFS support for ARM based systems, please follow the below steps:"
    add_message "- dns install -y kernel-devel kernel-headers dkms libtirpc-devel libblkid-devel libuuid-devel zlib-devel"
    add_message "- git clone https://github.com/openzfs/zfs.git"
    add_message "- cd zfs"
    add_message "- sh autogen.sh"
    add_message "- ./configure"
    add_message "- make -s -j8"
    add_message "- make install"
    show_message
  else
    yes y | dnf -y install https://zfsonlinux.org/epel/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm
    yes y | dnf -y install zfs zfs-dkms
    echo "zfs" >> /etc/modules-load.d/zfs.conf
    modprobe zfs
  fi
fi

if [ ! -f site/hosts ]; then
  add_message "Please modify the site/hosts.example and save it as site/hosts"  
else
  if ! grep -q "^$(hostname -s)\s*" site/hosts; then
    add_message "Please note the hostnames are not matching (see site/hosts)."
  fi
fi
if [ ! -f site/group_vars/all.yml ]; then
    add_message "Please modify the site/group_vars/all.yml.example and save it as site/group_vars/all.yml"
else
  if ! grep -q "^trix_ctrl1_hostname:\s*$(hostname -s)\s*$" site/group_vars/all.yml; then
    add_message "Please note the hostnames are not matching (see site/group_vars/all.yml)."
  fi
fi
add_message "Please configure the network before starting Ansible"

touch /etc/trinity/prepare.done
show_message


