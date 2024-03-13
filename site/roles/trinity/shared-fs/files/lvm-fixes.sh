#!/bin/bash

LVM_CONF=/etc/lvm/lvm.conf

LVM_DISKS=$(cat /tmp/lvm_filter.dat | grep -v '^#')
find /dev -type l -exec echo -n {}'=' \; -exec readlink -f {} \; > /tmp/dev-links.dat

FILTER="["
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
		EXCL=$(grep $REAL_DISK /tmp/dev-links.dat | awk -F'=' '{ print $1 }')
		for F in $EXCL; do
			echo $F
			FILTER="$FILTER \"r|$F|\","
		done
		if [ "$DISK" != "$REAL_DISK" ]; then
			echo $DISK
			FILTER="$FILTER \"r|$REAL_DISK|\","
		fi
		echo
	fi
done
FILTER="$FILTER \"a|.*|\" ]"
echo "filter = $FILTER"

VOLUMES="["
VGROUPS=$(cat /tmp/lvm_volumes.dat | grep -v '^#' )
if [ "$VGROUPS" ]; then
	VGROUPS=$(echo $VGROUPS | sed -e 's/ / -e /g')
	VGS=$(vgs | grep -v arning | tail -n+2 | awk '{ print $1 }' | grep -v -e $VGROUPS)
	for V in $VGS; do
		VOLUMES="$VOLUMES \"$V\","
	done
	VOLUMES=$(echo $VOLUMES | sed -e 's/,$//')
fi
VOLUMES="$VOLUMES ]"

echo "volume_list = $VOLUMES"

DEVICE_PRESENT=$(grep '^\s*use_devicesfile\s*=' $LVM_CONF)
FILTER_PRESENT=$(grep '^\s*filter\s*=' $LVM_CONF)
VOLUMES_PRESENT=$(grep '^\s*volume_list\s*=' $LVM_CONF)

if [ "$DEVICE_PRESENT" ]; then
	sed -i "s%^\(\s*use_devicesfile\s*=.*\)$%# TRINITYX \1\n\tuse_devicesfile = 0%g" $LVM_CONF
else
	echo -e "\tuse_devicesfile = 0" > /tmp/__lvm_device.dat
	sed -i '/^devices {/r /tmp/__lvm_device.dat' $LVM_CONF
fi
if [ "$FILTER_PRESENT" ]; then
	sed -i "s%^\(\s*filter\s*=.*\)$%# TRINITYX \1\n\tfilter = $FILTER%g" $LVM_CONF
else
	echo -e "\tfilter = $FILTER" > /tmp/__lvm_filter.dat
	sed -i '/^devices {/r /tmp/__lvm_filter.dat' $LVM_CONF
fi
if [ "$VOLUMES_PRESENT" ]; then
	sed -i "s%^\(\s*volume_list\s*=.*\)%# TRINITYX \1\n\tvolume_list = $VOLUMES%g" $LVM_CONF
else
	echo -e "\tvolume_list = $VOLUMES" > /tmp/__lvm_volumes.dat
	sed -i '/^activation {/r /tmp/__lvm_volumes.dat' $LVM_CONF
fi

