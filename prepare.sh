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
  yum install curl tar git epel-release -y

  if [[ `grep -i PRETTY_NAME="Red Hat Enterprise Linux 9" /etc/redhat-release` ]]; then
    # subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms
    # yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
    yum install ansible-core -y
    ansible-galaxy collection install ansible.posix
    ansible-galaxy collection install community.general
    ansible-galaxy collection install community.mysql
    ansible-galaxy collection install community.rabbitmq
    ansible-galaxy collection install community.grafana
  # elif [[ `grep -i PRETTY_NAME="Red Hat Enterprise Linux 9" /etc/redhat-release` ]]; then
    subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms
    # yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y
    yum install ansible-core -y
    ansible-galaxy collection install ansible.posix
    ansible-galaxy collection install community.general
    ansible-galaxy collection install community.mysql
    ansible-galaxy collection install community.rabbitmq
    ansible-galaxy collection install community.grafana
  elif [[ `grep -i PRETTY_NAME="CentOS Stream 9" /etc/redhat-release` ]]; then
    yum install ansible  -y
    yum --enablerepo=crb install perl-IPC-Run -y
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
