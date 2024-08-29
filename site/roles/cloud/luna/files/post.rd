if [ -f /tmp/disk.dat ]; then
    DISK=$(cat /tmp/disk.dat)

    mkdir /sysroot/proc /sysroot/dev /sysroot/sys

    echo "${DISK}   /       ext4    defaults        1 1" >> /sysroot/etc/fstab
else
    for DISK in /dev/sda /dev/nvme0n1; do
        ls $DISK &> /dev/null
        if [ "$?" == "0" ]; then
            break
        else
            DISK=""
        fi
    done
    if [ "$DISK" == "" ]; then
        echo "I do not have a disk! Help!!!"
        exit 1
    fi

    ROOTPT=$(parted $DISK print|grep -A100 Number|grep -i root|awk '{ print $1 }')

    mkdir /sysroot/proc /sysroot/dev /sysroot/sys

    if [[ ! -b ${DISK}${ROOTPT} ]] && [[ -b ${DISK}p${ROOTPT} ]]; then
        ROOTP="p${ROOTP}"
    fi
 
    echo "${DISK}${ROOTPT}   /       ext4    defaults        1 1" >> /sysroot/etc/fstab
fi
