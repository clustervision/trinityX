
Custom storage configurations for compute nodes
===============================================

As you have seen in the luna documentation, by default, the compute nodes are provisioned in diskless mode::

    # luna group show compute --partscript

    mount -t tmpfs tmpfs /sysroot


What follows are examples of different partitioning schemes that could be used on the compute nodes.


Simple diskful setup
--------------------

The following luna partitioning script will, on every reboot, delete and re-partition the ``/dev/sda`` disk according to the scheme:

    - ``/dev/sda1`` as a boot partition
    - ``/dev/sda2`` as a partition for the root file system

The script only makes use of Linux utilities that are available at provisioning time like ``parted`` and ``mkfs.ext4``::

	parted /dev/sda -s 'mklabel msdos'
	parted /dev/sda -s 'rm 1; rm 2'
	parted /dev/sda -s 'mkpart p ext2 1 256m'
	parted /dev/sda -s 'mkpart p ext3 256m 100%'
	parted /dev/sda -s 'set 1 boot on'

	mkfs.ext2 /dev/sda1
	mkfs.ext4 /dev/sda2

	mount /dev/sda2 /sysroot

	mkdir /sysroot/boot
	mount /dev/sda1 /sysroot/boot

It may be necessary to format the compute disks using a different filesystem which is not included in the partitioning script run within the ramdisk. In such cases, update the ``dracut`` configuration in the osimage to include the desired filesystem support and utilities and then pack it up.


LVM based scheme
----------------

Sometimes, it might be useful to have an LVM based disk layout on the compute nodes, either for the root filesystem or for scratch storage.

The following is an example of a simple LVM partitioning scheme that uses the logical volume ``storage/root`` for the root filesystem on the compute nodes::

    # Partition the sda disk
	parted /dev/sda -s 'mklabel msdos'
	parted /dev/sda -s 'rm 1; rm 2'
	parted /dev/sda -s 'mkpart p ext2 1 256m'
	parted /dev/sda -s 'mkpart p ext3 256m 100%'
	parted /dev/sda -s 'set 1 boot on'

    # Update the LVM locking type which is set to read-only by default
    sed -ie 's|\(\s*locking_type\)\s*=.*|\1 = 1|' /etc/lvm/lvm.conf

    # Destroy any previously created PVs
    lvm lvchange -a n storage
    echo y | lvm pvremove /dev/sda2 -f -f

    # Create PVs, VGs and LVs
    lvm pvcreate /dev/sda2 -f
    lvm vgcreate storage /dev/sda2 -f
    lvm lvcreate storage -L 5g --name root

    # Format boot and root disks
	mkfs.ext2 /dev/sda1
	mkfs.ext4 /dev/storage/root

	# Mount disks to their appropriate locations
	mkdir /sysroot/boot
	mount /dev/storage/root /sysroot
	mount /dev/sda1 /sysroot/boot

Do note that for the above to work, some changes need to be made to the osimage:

- ``lvm`` dracut module must be enabled in luna::

    # luna osimage change compute --dracutmodules 'luna,-i18n,-plymouth,lvm'

- ``lvm2`` must be installed in the osimage::

    # lchroot compute yum install lvm2

.. note:: This example serves only as a sample LVM based configuration. Using the same methodology, more complex configurations can be achieved.


Software RAID1 scheme
---------------------


