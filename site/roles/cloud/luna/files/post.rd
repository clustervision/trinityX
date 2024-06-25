DISK=/dev/sda
ROOTPT=$(parted $DISK print|grep -A100 Number|grep -i root|awk '{ print $1 }')

mkdir /sysroot/proc /sysroot/dev /sysroot/sys
 
cat << EOF >> /sysroot/etc/fstab
${DISK}${ROOTPT}   /       ext4    defaults        1 1
EOF
