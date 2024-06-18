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
  local MESG=$1
  local CONFIRM=''
  while [ ! "$CONFIRM" ]; do
    case $DEFAULT in
      [Yy]|yes|Yes)
        echo -n "$1? (<y>|n): "
        ;;
      *)
        echo -n "$1? (y|<n>): "
        ;;
    esac
    read -t 600 CONFIRM
    RET=$?
    if [ "$RET" == "142" ]; then
      CONFIRM=$DEFAULT
    fi
    case $CONFIRM in
      [Yy]|yes|Yes)
         echo yes
         ;;
      [Nn]|no|No)
         echo no
         ;;
    esac
  done
}

function store_config() {
  key=$1
  value=$2
  if [ -f /etc/trinity/prepare.conf ] && [ "$(grep '^'$key'=' /etc/trinity/prepare.conf)" ]; then
    sed -i 's/^'$key'=.*$/'$key'='$value'/' /etc/trinity/prepare.conf
  else
    echo "$key=$value" >> /etc/trinity/prepare.conf
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

if [[ `getenforce` == "Disabled" ]]; then
    add_message "SELinux in disabled mode is not supported. Please reboot to run in permissive mode"
    if [[ `grep "^SELINUX=disabled$" /etc/selinux/config` ]]; then
        sed -i 's/SELINUX=disabled/SELINUX=permissive/g' /etc/selinux/config
        show_message
        exit 1
    fi
fi
if [ ! -f TrinityX.pdf ]; then
  add_message "Please run from within the cloned TrinityX folder"
else
  # To disable SElinux on the controller node
  setenforce 0
  sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

  if [ ! "$INSIDE_RUNNER" ]; then
    if [ -f site/tui_configurator ]; then
        rm -f site/tui_configurator
    fi
    if [ ! "$(which wget)" ]; then
        dnf -y install wget
    fi
    TRIX_VER=$(grep 'trix_version' site/group_vars/all.yml.example 2> /dev/null | grep -oE '[0-9\.]+' || echo '14.1')
    wget --directory-prefix site/ https://updates.clustervision.com/trinityx/${TRIX_VER}/install/tui_configurator
    chmod 755 site/tui_configurator
  fi

  # inside a runner (test mode) we do not update the kernel.
  if [ "$INSIDE_RUNNER" ]; then
      yum update -y --exclude=kernel*
  else
      yum update -y
  fi
  yum install curl tar git -y

  REDHAT_RELEASE=''
  if  [[ `grep -i "Red Hat Enterprise Linux 8" /etc/os-release` ]]; then
    REDHAT_RELEASE=8
  elif  [[ `grep -i "Red Hat Enterprise Linux 9" /etc/os-release` ]]; then
    REDHAT_RELEASE=9
  fi
  if [ "$REDHAT_RELEASE" ]; then
    subscription-manager repos --enable codeready-builder-for-rhel-${REDHAT_RELEASE}-x86_64-rpms
    yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${REDHAT_RELEASE}.noarch.rpm -y
    yum install ansible-core -y
    yum install ansible -y
  else
    yum install epel-release -y
    yum install ansible -y
  fi

  ansible-galaxy install OndrejHome.pcs-modules-2

  # kernel check. Did we pull in a newer kernel?
  CURRENT_KERNEL=$(uname -r)
  LATEST_KERNEL=$(ls -tr /lib/modules/|tail -n1)

  if [ "$CURRENT_KERNEL" != "$LATEST_KERNEL" ] && [ ! "$INSIDE_RUNNER" ]; then
    add_message "Current running kernel is not the latest installed. It comes highly recommended to reboot prior continuing installation."
    add_message "after reboot, please re-run prepare.sh to make sure all requirements are met."
    show_message
    CONFIRM = $(get_confirmation n "Do you want to proceed with current kernel")
    if [ "$CONFIRM" != "yes" ]; then
      exit 1
    fi
  fi

  if [ ! "$WITH_ZFS" ] && [ ! "$INSIDE_RUNNER" ]; then
    add_message "Would you prefer to include ZFS?" 
    add_message "ZFS is supported in the shared_fs_disk/HA role. If you prefer to use ZFS there, please confirm below."
    show_message
    WITH_ZFS = $(get_confirmation y "Do you want to install ZFS")
  fi
  store_config 'WITH_ZFS' $WITH_ZFS

  if [ "$WITH_ZFS" == "yes" ] || [ "$INSIDE_RUNNER" ]; then
    yes y | dnf -y install https://zfsonlinux.org/epel/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm
    yes y | dnf -y install zfs zfs-dkms
    echo "zfs" >> /etc/modules-load.d/zfs.conf
    modprobe zfs
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
fi

touch /etc/trinity/prepare.done
show_message


