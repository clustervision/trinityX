
Hints and tips for a Luna installation
======================================


Setting up a compute node image
-------------------------------

.. note:: This chapter assumes that you are familiar with the Trinity X configuration tool and the configuration files that it uses. If not, please refer to the general `Documentation`_ first.

Trinity X includes configuration files to create automatically a basic compute node images. When receiving a new cluster this task will have been done already by our engineers and the image will be integrated in your provisioning system, in that case Luna.


Cloning an existing image
~~~~~~~~~~~~~~~~~~~~~~~~~

The easiest way to get a new image for modifications is to clone an existing one. For example::

    # luna osimage list
    +------------+---------------------------------------------+-------------------------------+
    | Name       | Path                                        | Kernel version                |
    +------------+---------------------------------------------+-------------------------------+
    | compute    | /trinity/images/compute-2016-09-22-12-29    | 3.10.0-327.28.3.el7.x86_64    |
    +------------+---------------------------------------------+-------------------------------+
    
    # luna osimage clone -n compute -t new-compute -p /trinity/images/new-compute
    /trinity/images/compute-2016-09-22-12-29 => /trinity/images/new-compute
    
    # luna osimage list
    +----------------+---------------------------------------------+-------------------------------+
    | Name           | Path                                        | Kernel version                |
    +----------------+---------------------------------------------+-------------------------------+
    | compute        | /trinity/images/compute-2016-09-22-12-29    | 3.10.0-327.28.3.el7.x86_64    |
    | new-compute    | /trinity/images/new-compute                 | 3.10.0-327.28.3.el7.x86_64    |
    +----------------+---------------------------------------------+-------------------------------+


Creating a new image
~~~~~~~~~~~~~~~~~~~~

In some other cases you may prefer to start from a fresh image. In that case use the Trinity X configuration tool and the provided configuration files::

    # ./configure.sh images-create-compute.cfg

.. note:: The location of ``configure.sh`` is not fixed, but it will often be found in ``/root/trinityX/configuration``

This will build a new compute image. The path of the image is shown in the last message displayed, substitute it in the examples below.


Adding images to Luna and packing them
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Adding node images to Luna is a two-step process:

1. add the image, which creates an entry in Luna's database for it;

2. pack the image, which prepares it for deployment.

When cloning an existing image there is no need to add it, as the cloning process does it automatically. Otherwise::

    # luna osimage add -n compute -p /trinity/images/compute-2016-09-23-15-22
    
    # luna osimage list
    +------------+---------------------------------------------+-------------------------------+
    | Name       | Path                                        | Kernel version                |
    +------------+---------------------------------------------+-------------------------------+
    | compute    | /trinity/images/compute-2016-09-23-15-22    | 3.10.0-327.36.1.el7.x86_64    |
    +------------+---------------------------------------------+-------------------------------+
    
    # luna osimage show -n compute
    +------------------+---------------------------------------------+
    | Parameter        | Value                                       |
    +------------------+---------------------------------------------+
    | name             | compute                                     |
    | dracutmodules    | luna,-i18n,-plymouth                        |
    | kernmodules      | ipmi_devintf,ipmi_si,ipmi_msghandler        |
    | kernopts         | None                                        |
    | kernver          | 3.10.0-327.36.1.el7.x86_64                  |
    | path             | /trinity/images/compute-2016-09-23-15-22    |
    +------------------+---------------------------------------------+

Packing is another one-step process::

    # luna osimage pack -n compute
    Creating tarball.
    Done.
    Creating torrent.
    Done.
    Copying kernel & packing inirtd.
    Turning off host-only mode: '/run' is not mounted!
    Done.
    
    # luna osimage show -n compute
    +------------------+-------------------------------------------------+
    | Parameter        | Value                                           |
    +------------------+-------------------------------------------------+
    | name             | compute                                         |
    | dracutmodules    | luna,-i18n,-plymouth                            |
    | initrdfile       | compute-initramfs-3.10.0-327.36.1.el7.x86_64    |
    | kernfile         | compute-vmlinuz-3.10.0-327.36.1.el7.x86_64      |
    | kernmodules      | ipmi_devintf,ipmi_si,ipmi_msghandler            |
    | kernopts         | None                                            |
    | kernver          | 3.10.0-327.36.1.el7.x86_64                      |
    | path             | /trinity/images/compute-2016-09-23-15-22        |
    | tarball          | 9ba09615-f312-4680-b4c4-1a318cbb1d2f            |
    | torrent          | b7a05f96-4eac-4c67-b783-18976a9fe312            |
    +------------------+-------------------------------------------------+

At that point the image is ready. You may want to do additional customizations or specify `Custom kernel version and parameters`, in which case you will have to remember to repack afterwards. Otherwise, we are done with the image.


Assigning the image to a group
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The next step is to assign the new image to a group. As there is only one image per group, either you assign the image to an existing group or you create a new group for it. In this case I'll create a group called ``compute`` (``-n``), using the osimage called ``compute`` too (``-o``), ``enp0s3`` as the default interface and no BMC setup::

    # luna group add -n compute -o compute -i enp0s3
    
    # luna group list
    +------------+--------------+--------------------------+
    | Name       | Osimage      | Interfaces               |
    +------------+--------------+--------------------------+
    | compute    | [compute]    | BMC:None, enp0s3:None    |
    +------------+--------------+--------------------------+
    
    # luna group show -n compute
    +---------------+-------------------------------------------------+
    | Parameter     | Value                                           |
    +---------------+-------------------------------------------------+
    | name          | compute                                         |
    | bmcnetwork    | None                                            |
    | bmcsetup      | None                                            |
    | boot_if       | None                                            |
    | interfaces    | BMC:None, enp0s3:None                           |
    | osimage       | [compute]                                       |
    | partscript    | mount -t tmpfs tmpfs /sysroot                   |
    | postscript    | cat <<EOF>>/sysroot/etc/fstab                   |
    |               | tmpfs   /       tmpfs    defaults        0 0    |
    |               | EOF                                             |
    | prescript     |                                                 |
    | torrent_if    | None                                            |
    +---------------+-------------------------------------------------+

.. note:: Luna groups contain a fair amount of configuration that is applied to all members of that group. If you have different nodes that have a slightly different configuration, then in most cases you will need more than one group.


Configuring the group: booting
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, new Luna groups are configured to boot their nodes diskless, with the image stored in RAM. This is the configuration shown above. If you will boot your nodes diskless, then there is nothing else to do and you can skip to the next subchapter.

.. note:: Diskless Luna nodes need at least twice as much memory as the size of the image directory. This isn't usually a problem on real HPC hardware, but it has to be taken into account when running VMs.

Another option is to install the osimage to the disk. For that you will have to modify at least the following parameters:

- the ``partscript``, which creates the partitions on the node and formats them at installation time;

- the ``postscript``, which does the final setup at the end of the installation process.

.. warning:: Those are regular shell scripts. They are not interactive. Due to limitations of the initrd used during the installation process, few commands are available although they are enough in the majority of cases. If your hardware requires something else, please see `Adding a file or command to the installation initrd`_.

The following examples are the scripts that I use for my own test system. On those nodes the HDD appears as ``/dev/sda``::

    # cat luna-partscript 
    parted /dev/sda -s 'mklabel msdos'
    parted /dev/sda -s 'mkpart p ext4 1 256m'
    parted /dev/sda -s 'mkpart p ext4 256m 100%'
    parted /dev/sda -s 'set 1 boot on'
    mkfs.ext4 /dev/sda1
    mkfs.ext4 /dev/sda2
    mount /dev/sda2 /sysroot
    mkdir /sysroot/boot
    mount /dev/sda1 /sysroot/boot
    
    # cat luna-postscript 
    mount -o bind /proc /sysroot/proc
    mount -o bind /dev /sysroot/dev
    chroot /sysroot /bin/bash -c "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg; /usr/sbin/grub2-install /dev/sda"
    chroot /sysroot /bin/bash -c "echo '/dev/sda2 / ext4 defaults 0 0' >> /etc/fstab"
    umount /sysroot/dev
    umount /sysroot/proc

Some comments:

- The ``partscript`` runs before the installation. The newly created root partition must be mounted in ``/sysroot``, and anything else mounted under that.

- The ``postscript`` does the post-installation setup, including installing the boot loader and setting up ``/etc/fstab``. If you need to mount network filesystems that are not part of the default node image, this may be the place to do it. (The Trinity X standard NFS mounts are configured during image creation -- check ``etc/fstab`` in your image directory.)

- The bind mounts and unmounts in the ``postscript`` are required by the GRUB2 installer, to detect the hardware and partition table. Keep those in.

Now we can apply those configurations::

    # luna group change -n compute --partscript --edit < luna-partscript
    
    # luna group change -n compute --postscript --edit < luna-postscript

    # luna group show -n compute
    +---------------+----------------------------------------------------------------------------------------------------------------------+
    | Parameter     | Value                                                                                                                |
    +---------------+----------------------------------------------------------------------------------------------------------------------+
    | name          | compute                                                                                                              |
    | bmcnetwork    | None                                                                                                                 |
    | bmcsetup      | None                                                                                                                 |
    | boot_if       | None                                                                                                                 |
    | interfaces    | BMC:None, enp0s3:None                                                                                                |
    | osimage       | [compute]                                                                                                            |
    | partscript    | parted /dev/sda -s 'mklabel msdos'                                                                                   |
    |               | parted /dev/sda -s 'mkpart p ext4 1 256m'                                                                            |
    |               | parted /dev/sda -s 'mkpart p ext4 256m 100%'                                                                         |
    |               | parted /dev/sda -s 'set 1 boot on'                                                                                   |
    |               | mkfs.ext4 /dev/sda1                                                                                                  |
    |               | mkfs.ext4 /dev/sda2                                                                                                  |
    |               | mount /dev/sda2 /sysroot                                                                                             |
    |               | mkdir /sysroot/boot                                                                                                  |
    |               | mount /dev/sda1 /sysroot/boot                                                                                        |
    |               |                                                                                                                      |
    | postscript    | mount -o bind /proc /sysroot/proc                                                                                    |
    |               | mount -o bind /dev /sysroot/dev                                                                                      |
    |               | chroot /sysroot /bin/bash -c "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg; /usr/sbin/grub2-install /dev/sda"    |
    |               | chroot /sysroot /bin/bash -c "echo '/dev/sda2 / ext4 defaults 0 0' >> /etc/fstab"                                    |
    |               | umount /sysroot/dev                                                                                                  |
    |               | umount /sysroot/proc                                                                                                 |
    |               |                                                                                                                      |
    | prescript     |                                                                                                                      |
    | torrent_if    | None                                                                                                                 |
    +---------------+----------------------------------------------------------------------------------------------------------------------+


.. note:: If we hadn't redirected the input of the ``luna group change`` commands, it would have started an interactive editor (``vi``) to let us do our modifications.


Configuring the group: networking
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Regardless of the booting mode, we need to configure networking. This will include:

- connecting a network to the interface(s);

- configuring the interface(s);

- setting the boot interface (optional);

Luna offers other possibilities, those are only the three essential ones.

A network called ``cluster`` is automatically created when Trinity X is configured. On a production-ready system you will find others, but for those examples we'll assume that it is the only one available.

The IP subnet and DHCP ranges are defined as part of the network. An interface inherits the configuration of the network it's connected to::

    # luna network list
    +------------+---------------------+
    | Name       | Network             |
    +------------+---------------------+
    | cluster    | 192.168.124.0/24    |
    +------------+---------------------+
    
    # luna network show -n cluster
    +----------------+--------------------+
    | Parameter      | Value              |
    +----------------+--------------------+
    | name           | cluster            |
    | NETWORK        | 192.168.124.0      |
    | PREFIX         | 24                 |
    | ns_hostname    | ref-centos7        |
    | ns_ip          | 192.168.124.254    |
    +----------------+--------------------+
    
    # luna group change -n compute -i enp0s3 --setnet cluster

By default any interface only has a very thin configuration, which is generated automatically by Luna and will always be inserted *before* all user customization::

    # luna group change -n compute -i enp0s3
    NETWORK=192.168.124.0
    PREFIX=24

The IP address is provided via DHCP for a standard configuration, so we only need to make sure that it's enabled at boot::

    # echo ONBOOT=yes | luna group change -n compute -i enp0s3 --edit
    
    # luna group change -n compute -i enp0s3
    NETWORK=192.168.124.0
    PREFIX=24
    ONBOOT=yes

Finally we can specify the boot interface, which in this case will be the same as the main interface. The main role for that option is to allow sysadmins to specify a different provisioning interface, for example to install over Infiniband. A side benefit of setting it is that the node will have its final IP during the installation process, making SSH into it a bit easier. If not set, the IP during installation will be a dynamic one. So::

    # luna group change -n compute --boot_if enp0s3

And the final group configuration is::

    # luna group show -n compute
    +---------------+----------------------------------------------------------------------------------------------------------------------+
    | Parameter     | Value                                                                                                                |
    +---------------+----------------------------------------------------------------------------------------------------------------------+
    | name          | compute                                                                                                              |
    | bmcnetwork    | None                                                                                                                 |
    | bmcsetup      | None                                                                                                                 |
    | boot_if       | enp0s3                                                                                                               |
    | interfaces    | BMC:None, enp0s3:[cluster]:192.168.124.0/24                                                                          |
    | osimage       | [compute]                                                                                                            |
    | partscript    | parted /dev/sda -s 'mklabel msdos'                                                                                   |
    |               | parted /dev/sda -s 'mkpart p ext4 1 256m'                                                                            |
    |               | parted /dev/sda -s 'mkpart p ext4 256m 100%'                                                                         |
    |               | parted /dev/sda -s 'set 1 boot on'                                                                                   |
    |               | mkfs.ext4 /dev/sda1                                                                                                  |
    |               | mkfs.ext4 /dev/sda2                                                                                                  |
    |               | mount /dev/sda2 /sysroot                                                                                             |
    |               | mkdir /sysroot/boot                                                                                                  |
    |               | mount /dev/sda1 /sysroot/boot                                                                                        |
    |               |                                                                                                                      |
    | postscript    | mount -o bind /proc /sysroot/proc                                                                                    |
    |               | mount -o bind /dev /sysroot/dev                                                                                      |
    |               | chroot /sysroot /bin/bash -c "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg; /usr/sbin/grub2-install /dev/sda"    |
    |               | chroot /sysroot /bin/bash -c "echo '/dev/sda2 / ext4 defaults 0 0' >> /etc/fstab"                                    |
    |               | umount /sysroot/dev                                                                                                  |
    |               | umount /sysroot/proc                                                                                                 |
    |               |                                                                                                                      |
    | prescript     |                                                                                                                      |
    | torrent_if    | None                                                                                                                 |
    +---------------+----------------------------------------------------------------------------------------------------------------------+


Final words
~~~~~~~~~~~

At that point everything is done:

- the image was built and added to a new group;

- the new group was configured for local storage and networking.

The only things left now are to add compute nodes to that group and to provision them.



Generating pdsh groups from Luna groups
---------------------------------------

`pdsh <https://github.com/grondo/pdsh>`_ is a popular parallel shell tool, allowing to run the same command or set of commands on multiple machines at the same time. It is installed by default on Trinity X systems, and the sysadmins may chose to use it over other alternatives.

As of Trinity X release 1 there is no integration of Luna with ``pdsh``, and the configuration files required by ``pdsh`` have to be created by the sysadmins. Although it's possible to write a script around the output of ``luna node list``, the Trinity X source tree comes with a pre-written tool: ``scripts/luna2pdsh.sh``.

A typical output would be similar to this::

    [root@controller trinityX]# ./scripts/luna2pdsh.sh 
    
    Group: compute
    node001
    node002
    
    Group: compute2
    node003

It will create group files in ``/etc/dsh/groups``, that can be used with the ``dshgroup`` module of ``pdsh``::

    # pdsh -g compute hostname
    node001
    node002

Note that the files include all node names known to Luna, including those that haven't been discovered yet (i.e., Luna doesn't know their MAC addresses, and no entry will exist in the DNS records). If you have added nodes recently, boot them up at least once to make sure that Luna discovers them, then run ``luna cluster makedns`` followed by the ``luna2pdsh.sh`` script again.



Custom kernel version and parameters
------------------------------------

As Luna provides the running kernel to the compute nodes via PXE and TFTP, it controls which kernel runs and provides all the boot parameters. This design choice is advantageous for multiple reasons, like central management of kernel parameters or booting an alternative kernel without needing to modify the node images.

The default kernel on which the image boots is picked by Luna when the osimage is added with ``luna osimage add ...``.

.. note:: When there is more than one kernel, the first one returned by ``rpm`` is used as the default kernel, without further sorting. For that reason it may not be the most recent one, or the latest one installed. You should always check your kernel version

The following examples assume that the image was added to Luna under the name ``compute``.

By default the osimages boot without specific kernel parameters (the ``kernopts`` line)::

    # luna osimage show -n compute
    +------------------+-------------------------------------------------+
    | Parameter        | Value                                           |
    +------------------+-------------------------------------------------+
    | name             | compute                                         |
    | dracutmodules    | luna,-i18n,-plymouth                            |
    | initrdfile       | compute-initramfs-3.10.0-327.36.1.el7.x86_64    |
    | kernfile         | compute-vmlinuz-3.10.0-327.36.1.el7.x86_64      |
    | kernmodules      | ipmi_devintf,ipmi_si,ipmi_msghandler            |
    | kernopts         | None                                            |
    | kernver          | 3.10.0-327.36.1.el7.x86_64                      |
    | path             | /trinity/images/compute-2016-09-22-12-29        |
    | tarball          | fcae174d-d294-4ef5-b490-4e297fcc0612            |
    | torrent          | c174d617-e5c2-411e-a4c9-0d19be38014f            |
    +------------------+-------------------------------------------------+

Let's check which kernels are available in that image::

    # luna osimage show -n compute --kernver
    3.10.0-327.36.1.el7.x86_64 <=
    3.10.0-327.28.3.el7.x86_64

Which matches the installed RPMs::

    # rpm --root /trinity/images/compute-2016-09-22-12-29 -qa | grep kernel | sort
    kernel-3.10.0-327.28.3.el7.x86_64
    kernel-3.10.0-327.36.1.el7.x86_64
    kernel-devel-3.10.0-327.36.1.el7.x86_64
    kernel-headers-3.10.0-327.36.1.el7.x86_64
    kernel-tools-3.10.0-327.36.1.el7.x86_64
    kernel-tools-libs-3.10.0-327.36.1.el7.x86_64

So we have two versions here. Switching to a different one is straightforward::

    # luna osimage change -n compute --kernver 3.10.0-327.28.3.el7.x86_64
    
    # luna osimage show -n compute --kernver
    3.10.0-327.36.1.el7.x86_64
    3.10.0-327.28.3.el7.x86_64 <=

It's very much the same for kernel parameters. Let's assume that you want to add ``elevator=noop`` and ``kvm-intel.nested=1`` as you're experimenting with nested virtualization on your compute nodes::

    # luna osimage change -n compute --kernopts "elevator=noop kvm-intel.nested=1"

.. note:: This command overwrites all previous kernel parameters. If you want to add a parameter to a pre-existing list, you will have to specify all old and new parameters.

We can now check the configuration of the osimage again::

    # luna osimage show -n compute
    +------------------+-------------------------------------------------+
    | Parameter        | Value                                           |
    +------------------+-------------------------------------------------+
    | name             | compute                                         |
    | dracutmodules    | luna,-i18n,-plymouth                            |
    | initrdfile       | compute-initramfs-3.10.0-327.36.1.el7.x86_64    |
    | kernfile         | compute-vmlinuz-3.10.0-327.36.1.el7.x86_64      |
    | kernmodules      | ipmi_devintf,ipmi_si,ipmi_msghandler            |
    | kernopts         | elevator=noop kvm-intel.nested=1                |
    | kernver          | 3.10.0-327.28.3.el7.x86_64                      |
    | path             | /trinity/images/compute-2016-09-22-12-29        |
    | tarball          | fcae174d-d294-4ef5-b490-4e297fcc0612            |
    | torrent          | c174d617-e5c2-411e-a4c9-0d19be38014f            |
    +------------------+-------------------------------------------------+

Our changes have been recorded, but the ``kernfile`` and ``initrdfile`` are still the old ones. The reason for that is that we haven't repacked the image yet. Packing is the step at which all the configuration options are taken into account and the kernel and initrd files are extracted for PXE boot. Once all changes are done, pack the image and check again::

    # luna osimage pack -n compute -b
    Copying kernel & packing inirtd.
    Turning off host-only mode: '/run' is not mounted!
    Done.
    
    # luna osimage show -n compute
    +------------------+-------------------------------------------------+
    | Parameter        | Value                                           |
    +------------------+-------------------------------------------------+
    | name             | compute                                         |
    | dracutmodules    | luna,-i18n,-plymouth                            |
    | initrdfile       | compute-initramfs-3.10.0-327.28.3.el7.x86_64    |
    | kernfile         | compute-vmlinuz-3.10.0-327.28.3.el7.x86_64      |
    | kernmodules      | ipmi_devintf,ipmi_si,ipmi_msghandler            |
    | kernopts         | elevator=noop kvm-intel.nested=1                |
    | kernver          | 3.10.0-327.28.3.el7.x86_64                      |
    | path             | /trinity/images/compute-2016-09-22-12-29        |
    | tarball          | fcae174d-d294-4ef5-b490-4e297fcc0612            |
    | torrent          | c174d617-e5c2-411e-a4c9-0d19be38014f            |
    +------------------+-------------------------------------------------+

.. note:: The ``-b`` or ``--boot`` flag tells Luna to repack only the boot files, which are the kernel and initial ramdisk. As we haven't done any other change to the image this is enough, and saves us the time required to recreate the whole image tarball.

Now all is done and we can deploy nodes with the new kernel and parameters.

.. note:: Remember that this does not have immediate effect on running nodes. They will have to be re-provisioned to use the new kernel.

.. note:: As the osimage is a group parameter in Luna, any change at that level affects all groups configured to use this image. If the changes affect only a subset of those groups, the easiest way to deal with that is to clone the existing image, configure the subset of groups to use it, and apply the changes to the clone only. Run ``luna osimage clone -h`` for more details.



Compute node NIC naming
-----------------------

By default CentOS 7 uses new-style naming of network interfaces, based on the NIC type, their location in the machine, etc (eg. enp0s29u1u2). The name is decided either by the udev naming rules, or by the ``biosdevname`` module. The exact naming rules are documented in the SystemD / udev sources, and in the RHEL 7 documentation:

`Predictable network interface device names <https://github.com/systemd/systemd/blob/master/src/udev/udev-builtin-net_id.c>`_

`Consistent Network Device Naming <https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-Consistent_Network_Device_Naming.html>`_

In a few cases this may be more of a hindrance than anything. If you have good reasons for wanting the old naming scheme back (which comes with its own set of issues), you can specify boot kernel parameters for the osimage to revert to the old scheme. Assuming that the image was added to Luna as ``compute``, you can run::

    # luna osimage change -n compute --kernopts "net.ifnames=0 biosdevname=0"
    # luna osimage pack -n compute -b

For further details, see `Custom kernel version and parameters`_.



.. Relative file links

.. _Documentation: README.rst

