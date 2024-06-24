DISK=/dev/sda
NEXT=$(parted $DISK print|grep -A100 Number|grep root|awk '{ print $1 }')

mkdir /sysroot/proc /sysroot/dev /sysroot/sys
 
cat << EOF >> /sysroot/etc/fstab
${DISK}${NEXT}   /       ext4    defaults        1 1
EOF
