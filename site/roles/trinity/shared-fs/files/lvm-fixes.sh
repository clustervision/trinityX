#!/bin/bash


LVM_DISKS=$(cat /tmp/lvm-disks.dat)

find /dev -type l -exec echo -n {}'=' \; -exec readlink -f {} \; > /tmp/dev-links.dat


for DISK in $LVM_DISKS; do
	REAL_DISK=""
	# we have deeper nested disks, i.e. not /dev/vda or so
	DISK_TYPE=$(file -b $DISK | awk '{ print $1" "$2 }')
	case $DISK_TYPE in
		'symbolic link' )
			REAL_DISK=$(readlink -f $DISK)
		;;
		'block special' )
			REAL_DISK=$DISK
		;;
		* )
			echo "I do not know how to handle $DISK being $DISK_TYPE"
		;;
	esac
	if [ "$REAL_DISK" ]; then
		echo "------------ $DISK -- $REAL_DISK -------------"
		grep $REAL_DISK /tmp/dev-links.dat | awk -F'=' '{ print $1 }'
		echo
	fi

done

