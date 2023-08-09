#!/bin/bash
if [ ! -f TrinityX.pdf ]; then
  echo "Please run from within the cloned TrinityX folder"
else
  setenforce 0
  yum update -y
  yum install epel-release -y
  yum install curl tar ansible git python2-pip epel-release -y
  ansible-galaxy install OndrejHome.pcs-modules-2
  echo "#### Please configure the network before starting Ansible ####"
fi
