DISK=/dev/sda
ROOTTHERE=$(parted $DISK print|grep -A100 Number|grep -i root|awk '{ print $1 }')

if [ ! "$ROOTTHERE" ]; then
    for partition in $(parted $DISK print|grep -A100 Number|grep -v -e msftdata -e boot -e Number|awk '{ print $1 }'|grep -v '^$'); do
        parted $DISK rm $partition
    done

    parted $DISK -s 'mkpart root ext4 4g 100%'
fi

ROOTPT=$(parted $DISK print|grep -A100 Number|grep -i root|awk '{ print $1 }')

while [[ ! -b ${DISK}${ROOTPT} ]]; do sleep 1; done
 
mkfs.ext4 ${DISK}${ROOTPT}
mount ${DISK}${ROOTPT} /sysroot
