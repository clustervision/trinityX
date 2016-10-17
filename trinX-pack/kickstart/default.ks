lang en_US
keyboard us
timezone Europe/Amsterdam --isUtc
rootpw $1$NkijN4WX$nY0pLKZClSg5dLRwq2Ig8/ --iscrypted
#platform x86, AMD64, or Intel EM64T
text
cdrom
bootloader --location=mbr --append="crashkernel=auto"
# uncomment the following line for unattended install
#zerombr
autopart
auth --passalgo=sha512 --useshadow
selinux --enforcing
firewall --enabled
skipx
firstboot --disable
%packages
@core
%end
%post
sed -i 's/rhgb quiet//' /boot/grub/grub.conf
%end
