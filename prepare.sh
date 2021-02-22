#!/bin/bash
if [ ! -f TrinityX.pdf ]; then
  echo "Please run from within the cloned TrinityX folder"
else
  setenforce 0
  yum update -y
  curl https://updates.clustervision.com/luna/1.2/centos/luna-1.2.repo > /etc/yum.repos.d/luna-1.2.repo
  yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
  yum install curl tar ansible git luna-ansible python-pip -y
  ansible-galaxy install OndrejHome.pcs-modules-2
  if [ ! -d site/mitogen ]
  then
    curl https://codeload.github.com/mitogen-hq/mitogen/tar.gz/v0.2.9 --output mitogen.tar.gz
    tar -zxf mitogen.tar.gz
    mv mitogen-0.2.9 site/mitogen
    rm -f mitogen.tar.gz
  fi
  echo "#### Please configure the network before starting Ansible ####"
fi
