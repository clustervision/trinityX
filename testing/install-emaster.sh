#!/bin/bash

WORK_DIR=/root/quentin/trinityx
LOG=/root/quentin/emaster-log
VM_NAME=QLB-emaster

date | tee -a $LOG
echo "Starting install in 10 seconds, ALL DATA ON $VM_NAME WILL BE WIPED, hit CTRL-C to cancel"
sleep 10

# Preparing the ISO
echo "Building the ISO..."
$WORK_DIR/trinX-pack/builder -i /var/lib/libvirt/images/CentOS-7-x86_64-Minimal-1511.iso -m 88c0437f0a14c6e2c94426df9d43cd67 -b y -k $WORK_DIR/testing/emaster.ks > $LOG 2>&1
echo "Moving the ISO to /var/lib/libvirt/images..."
mv $WORK_DIR/trinX-pack/custom.iso /var/lib/libvirt/images/Centos-7-x86_64_Minimal-1511-KICKSTART.iso
echo "Shutting down the VM..."
virsh destroy $VM_NAME
echo "Ejecting the ISO just in case..."
virsh change-media $VM_NAME hda --eject

# Let's install
echo "Inserting the ISO into the VM..."
virsh change-media $VM_NAME hda --source /var/lib/libvirt/images/Centos-7-x86_64_Minimal-1511-KICKSTART.iso --insert
echo "Starting the VM"
virsh start $VM_NAME
VM_STATE=`virsh dominfo $VM_NAME | grep "State:" | awk '{print $2}'`
if [ "$VM_STATE" != "running" ]; then
   echo oops, VM is not running
   exit 1
fi
while [ "$VM_STATE" == "running" ]; do
    echo "Waiting until kickstart install has finished..."
    sleep 60
    VM_STATE=`virsh dominfo $VM_NAME | grep "State:" | awk '{print $2}'`
done
echo "Install complete, ejecting the ISO..."
virsh change-media $VM_NAME hda --eject

# First boot
echo "Booting the VM..."
virsh start $VM_NAME
while [ "$VM_STATE" != "" ]; do
    echo "Waiting until host is up..."
    sleep 10
    ping -c 1 emaster && VM_STATE=
done
echo "Host is up"
sleep 30

# SSH config
echo "Setting up password-less SSH..."
sed -i "/emaster/d" /root/.ssh/known_hosts
sshpass -p system ssh -o StrictHostKeyChecking=no emaster "mkdir /root/.ssh"
sshpass -p system ssh emaster "echo `cat /root/.ssh/id_rsa.pub` >> /root/.ssh/authorized_keys"
echo "Checking password-less SSH, running ssh emaster hostname:"
EMASTER_HOSTNAME=`ssh emaster hostname`
echo $EMASTER_HOSTNAME
if [ "$EMASTER_HOSTNAME" != "emaster" ]; then
    echo "oops, something went wrong"
    exit 1
fi
echo "Copying SSH keys from kvm2"
scp /root/.ssh/id_rsa{,.pub} emaster:/root/.ssh
ssh emaster 'echo "Host github.com" >> /root/.ssh/config'
ssh emaster 'echo "  StrictHostKeyChecking no" >> /root/.ssh/config'


# Pulling git and installing the beast
ssh emaster yum -y install git
ssh emaster git clone quentinleburel@github.com:clustervision/trinityx

# Starting the installation script
ssh emaster "cd /root/trinityx/configuration; ./configure.sh --dontstopmenow --nocolor emaster.cfg 2>&1 | tee -a /var/log/trinity-installer.log"


