#!/bin/bash
if [ ! -f TrinityX.pdf ]; then
  echo "Please run from within the cloned TrinityX folder"
else
  setenforce 0
  yum update -y
  curl https://updates.clustervision.com/luna/1.2/centos/luna-1.2.repo > /etc/yum.repos.d/luna-1.2.repo
  yum install epel-release -y
  yum install ansible git luna-ansible python-pip -y
  ansible-galaxy install OndrejHome.pcs-modules-2
  git clone https://github.com/dw/mitogen.git site/mitogen
  echo "#### Please configure the network before starting Ansible ####"
fi
