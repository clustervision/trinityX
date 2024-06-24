DISK=/dev/sda

for partition in $(parted $DISK print|grep -A100 Number|grep -v -e msftdata -e boot -e Number|awk '{ print $1 }'|grep -v '^$'); do
    parted $DISK rm $partition
done

parted $DISK -s 'mkpart root ext4 4g 100%'

NEXT=$(parted $DISK print|grep -A100 Number|grep root|awk '{ print $1 }')

while [[ ! -b ${DISK}${NEXT} ]]; do sleep 1; done
 
mkfs.ext4 ${DISK}${NEXT}
mount ${DISK}${NEXT} /sysroot
