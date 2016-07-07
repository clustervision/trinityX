lang en_US
keyboard us
timezone Europe/Amsterdam --isUtc
rootpw $1$NkijN4WX$nY0pLKZClSg5dLRwq2Ig8/ --iscrypted
#platform x86, AMD64, or Intel EM64T
reboot
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
%packages
@base
%end