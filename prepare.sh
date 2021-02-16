#!/bin/bash
if [ ! -f TrinityX.pdf ]; then
  echo "Please run from within the cloned TrinityX folder"
else
  setenforce 0
  yum update -y
  curl https://updates.clustervision.com/luna/1.2/centos/luna-1.2.repo > /etc/yum.repos.d/luna-1.2.repo
  yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
  yum install ansible git luna-ansible python-pip -y
  ansible-galaxy install OndrejHome.pcs-modules-2
  if [ ! -d site/mitogen ]
  then
    wget https://github.com/mitogen-hq/mitogen/archive/v0.2.9.zip
    unzip v0.2.9.zip
    mv mitogen-0.2.9 site/mitogen
    rm -f v0.2.9.zip
  fi
  echo "#### Please configure the network before starting Ansible ####"
fi
