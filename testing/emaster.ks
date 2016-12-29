lang en_US
keyboard us
timezone Europe/Amsterdam --isUtc
rootpw $1$NkijN4WX$nY0pLKZClSg5dLRwq2Ig8/ --iscrypted
#platform x86, AMD64, or Intel EM64T
poweroff
text
cdrom
bootloader --location=mbr --append="crashkernel=auto"
zerombr
clearpart --all --initlabel
autopart
auth --passalgo=sha512 --useshadow
selinux --enforcing
firewall --enabled
skipx
firstboot --disable
network --bootproto=dhcp --hostname=emaster --device=eth0
network --bootproto=static --ip=10.30.255.254 --netmask=255.255.0.0 --device=ens9
%packages
@core
%end
%post
sed -i 's/rhgb quiet//' /boot/grub/grub.conf
%end
