for DISK in /dev/sda /dev/nvme0n1; do
    if [[ -b $DISK ]]; then
        break
    else
        DISK=""
    fi
done
if [ "$DISK" == "" ]; then
    echo "I do not have a disk! Help!!!"
    exit 1
fi

ROOTTHERE=$(printf "fix\n"|parted ---pretend-input-tty $DISK print|grep -A100 Number|grep -i root|awk '{ print $1 }')

if [ "$ROOTTHERE" ]; then
    ROOTSIZE=$(parted $DISK unit MB print|grep '^\s*'$ROOTTHERE|awk '{ print $4 }'|grep -oE '[0-9]+' || echo 0)
    if [ "$ROOTSIZE" -lt "4500" ]; then
        echo "I have found a root partition, but its size $ROOTSIZE is too small."
        ROOTTHERE=""
    fi
fi

if [ ! "$ROOTTHERE" ]; then
    echo "(Re)creating a root partition."
    for partition in $(parted $DISK print|grep -A100 Number|grep -v -e msftdata -e boot -e Number|awk '{ print $1 }'|grep -v '^$'); do
        parted $DISK rm $partition
    done
    LAST=$(parted $DISK unit s print|grep -A100 Number|awk '{ print $3 }'|grep -oE "[0-9]+"|sort -n -r|grep -v "^$" -m 1)
    if [ "$LAST" ]; then
        NEXT=$[LAST+1]
        echo "Creating partition starting at ${NEXT}s to 100%"
        parted $DISK -s "mkpart root ext4 ${NEXT}s 100%"
        if [ "$?" != "0" ]; then
            echo "Attempting failsafe approach"
            parted $DISK -a optimal -s "mkpart root ext4 0% 100%"
        fi
    else
        echo "No suitable size found, Attempting failsafe approach"
        parted $DISK -s "mkpart root ext4 2g 100%"
    fi
fi

ROOTPT=$(parted $DISK print|grep -A100 Number|grep -i root|awk '{ print $1 }')

if [ ! "$ROOTPT" ]; then
    echo "Big error. could not find a suitable root partition. cannot continue"
    exit 1
fi

while [ 0 ]; do
    if [[ -b ${DISK}p${ROOTPT} ]]; then
        ROOTPT="p${ROOTPT}"
        break
    else
        if [[ -b ${DISK}${ROOTPT} ]]; then
            break
        fi
    fi
    sleep 2
done

if [ ! -d /tmp ]; then
    mkdir /tmp
fi
echo "${DISK}${ROOTPT}" > /tmp/disk.dat

umount -l ${DISK}${ROOTPT} &> /dev/null
mkfs.ext4 ${DISK}${ROOTPT}
mount ${DISK}${ROOTPT} /sysroot
