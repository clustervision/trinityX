#!/bin/bash
if [[ `getenforce` == "Disabled" ]]; then
    echo "SELinux in disabled mode is not supported. Please reboot to run in permissive mode"
    if [[ `grep "^SELINUX=disabled$" /etc/selinux/config` ]]; then
        sed -i 's/SELINUX=disabled/SELINUX=permissive/g' /etc/selinux/config
        exit 1
    else
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        exit 1
    fi
fi
if [ ! -f TrinityX.pdf ]; then
  echo "Please run from within the cloned TrinityX folder"
else
  # To disable SElinux on the controller node
  setenforce 0
  sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

  # if running on RedHat 8 or 9, install subscription-manager repos --enable ansible-XXXXXXXXXXXX


  yum update -y
  yum install epel-release -y
  yum install curl tar git epel-release -y

  if [[ `grep -i "Red Hat Enterprise Linux" /etc/redhat-release` ]]; then
    if [[ `grep -i "release 8" /etc/redhat-release` ]]; then
        yum install ansible-core  -y
    elif [[ `grep -i "release 9" /etc/redhat-release` ]]; then
        yum install ansible-core  -y

    fi
  else
    yum install ansible  -y
  fi

  ansible-galaxy install OndrejHome.pcs-modules-2

  if [ ! -f site/hosts ]; then
    echo "Please modify the site/hosts.example and save it as site/hosts"  
  else
    if ! grep -q "^$(hostname -s)\s*" site/hosts; then
      echo "Please note the hostnames are not matching (see site/hosts)."
    fi
  fi
  if [ ! -f site/group_vars/all.yml ]; then
     echo "Please modify the site/group_vars/all.yml.example and save it as site/group_vars/all.yml"
  else
    if ! grep -q "^trix_ctrl1_hostname:\s*$(hostname -s)\s*$" site/group_vars/all.yml; then
      echo "Please note the hostnames are not matching (see site/group_vars/all.yml)."
    fi
  fi
  echo
  echo "#### Please configure the network before starting Ansible ####"
fi
