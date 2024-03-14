#!/bin/bash

function add_message() {
  echo -e "$1\n" | fold -w70 -s >> /tmp/mesg.$$.dat
}

function show_message() {
  #echo $1 | fold -w70 -s > /tmp/warn.$$.dat
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

  yum update -y
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

  if [ "$CURRENT_KERNEL" != "$LATEST_KERNEL" ]; then
    add_message "Current running kernel is not the latest installed. It comes highly recommended to reboot prior continuing installation."
    add_message "after reboot, please re-run prepare.sh to make sure all requirements are met."
    add_message "If you insist on proceeding though, please confirm with 'go', anything else stops the installation."
    show_message
    echo -n "Please let me know your preference (go|<anything else>): "
    read -t 60 CONFIRM
    RET=$?
    if [ "$RET" == "142" ]; then
      CONFIRM='yes'
    fi
    if [ "$CONFIRM" != "yes" ]; then
       exit 1
    fi
  fi

  # experimental ZFS support
  yes y | dnf -y install https://zfsonlinux.org/epel/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm
  yes y | dnf -y install zfs zfs-dkms

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

show_message


