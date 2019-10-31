#!/bin/bash
setenforce 0
yum update -y
curl https://updates.clustervision.com/luna/1.2/centos/luna-1.2.repo > /etc/yum.repos.d/luna-1.2.repo
yum install epel-release -y
yum install git ansible luna-ansible -y
ssh-keygen -q -t rsa -b 4096
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
ansible-galaxy install OndrejHome.pcs-modules-2
echo "#### Please configure the network before starting Ansible ####"
