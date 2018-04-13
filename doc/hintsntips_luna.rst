
Hints and tips for a Luna installation
======================================


Setting up a compute node image
-------------------------------

.. note:: This chapter assumes familiarity with the TrinityX configuration tool and the configuration files that it uses. If not, please refer to the general :doc:`index` first.

TrinityX includes configuration files to automatically create a basic compute node image. Upon delivery of a new cluster, this will have been completed by ClusterVision engineers and the image will be integrated into the provisioning system, in this case Luna.


Cloning an existing image
~~~~~~~~~~~~~~~~~~~~~~~~~

The easiest way to get a new image for modifications is to clone an existing one. For example:

.. code-block:: console

    # luna osimage list
    +------------+----------------------------+-------------------------------+
    | Name       | Path                       | Kernel version                |
    +------------+----------------------------+-------------------------------+
    | compute    | /trinity/images/compute    | 3.10.0-693.17.1.el7.x86_64    |
    +------------+----------------------------+-------------------------------+

    # luna osimage clone compute -t new-compute -p /trinity/images/new-compute
    INFO:luna.osimage.compute:/trinity/images/compute => /trinity/images/new-compute

    # luna osimage list
    +----------------+--------------------------------+-------------------------------+
    | Name           | Path                           | Kernel version                |
    +----------------+--------------------------------+-------------------------------+
    | compute        | /trinity/images/compute        | 3.10.0-693.17.1.el7.x86_64    |
    | new-compute    | /trinity/images/new-compute    | 3.10.0-693.17.1.el7.x86_64    |
    +----------------+--------------------------------+-------------------------------+

Creating a new image
~~~~~~~~~~~~~~~~~~~~

In some cases it may be preferable to start from a fresh image. In that case, copy the existing playbook and change the name of the image (``image_name`` variable and ``hosts`` target)::

    # cp compute.yml new-compute.yml
    # sed -i -e 's/compute/new-compute/' new-compute.yml

In the event an image has been customized/more roles added, run ``ansible-playbook`` once finished::

    # ansible-playbook new-compute.yml

To speed up creation time, it is possible to disable packing of the image. This is handy when testing changes::

    # ansible-playbook --skip-tags=wrapup-images  new-compute.yml


Modifying images and packing them
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There are two approaches to creating new images in TrinityX: manually and via Ansible. The same is true for modifying images. 

In the manual approach, first clone the image with ``luna osimage clone`` and modify as a regular set of files or in chrooted environment.

Regarding the manual modification of an image's content: Luna has a tool called ``lchroot``. It is a wrapper around the good old ``chroot`` tool, but with some additions and integration with Luna. In particular, it mounts /dev, /proc, /sys filesystems on start and unmounts on exit. Don't try to pack the image if an ``lchroot`` session is running. Packing the image at this point will pack the content of the mentioned service filesystems and this is probably not desired.

The tool can also mock the kernel version allowing to install software which requires particular release::

    # uname -r
    3.10.0-693.17.1.el7.x86_64

    # lchroot new-compute
    IMAGE PATH: /trinity/images/new-compute
    chroot [root@new-compute /]$ uname -r
    3.10.0-693.5.2.el7.x86_64

Before packing the image, it may be desirable to change kernel options or the kernel version if several are installed::

    # luna osimage change new-compute --kernopts "console=ttyS1,115200n8 console=tty0 intel_pstate=disable"

To list installed kernels::

    # luna osimage show new-compute --kernver
    3.10.0-693.17.1.el7.x86_64 <=
    3.10.0-693.5.2.el7.x86_64

And to change::

    # luna osimage change new-compute --kernver 3.10.0-693.5.2.el7.x86_64

    # luna osimage show new-compute --kernver
    3.10.0-693.17.1.el7.x86_64
    3.10.0-693.5.2.el7.x86_64 <=

After customization is done, it is important to pack the image so that the changes are available to the nodes. Packing is done by a creating a tarball, creating a torrent-file from it, and adding it to the Luna DB. Everything will be done automatically when ``luna osimage pack`` is executed::

    # luna osimage pack new-compute
    INFO:root:Creating tarball.
    INFO:root:Done.
    INFO:root:Creating torrent.
    INFO:root:Done.
    INFO:root:Copying kernel & packing inirtd.
    INFO:root:Done.


In TrinityX's playbook, this task is done by the ``wrapup-images`` role::

    TASK [trinity/wrapup-images : Pack the image] **********************************
    changed: [new-compute.osimages.luna -> localhost]

Grabbing an image from a live node
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This method is handy when some software requires hardware to be physically present on a node to run its installation procedure. After installation is complete, it is possible to sync files back to the image. Before doing so, it is worthwhile to inspect ``--grab_exclude_list`` and ``--grab_filesystems`` options in order to limit the amount of data to be synced. To check what needs to be synced, ``--dry_run`` can be specified::

    # luna osimage grab new-compute --host node001 --dry_run
    INFO:luna.osimage.new-compute:Fetching / from node001
    INFO:luna.osimage.new-compute:Running command: /usr/bin/rsync -avxz -HAX -e "/usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" --progress --delete --exclude-from=/tmp/new-compute.excl_list.rsync.ybBx8D  --dry-run  root@node001:/ /trinity/images/new-compute/
    <...snip...>

Networks in Luna
~~~~~~~~~~~~~~~~

Networks in Luna have 3 main attributes: the name, the network itself, and the prefix::

    # luna network show cluster
    +----------------+-------------------+
    | Parameter      | Value             |
    +----------------+-------------------+
    | name           | cluster           |
    | NETWORK        | 10.141.0.0        |
    | PREFIX         | 16                |
    | include        | -                 |
    | ns_hostname    | controller        |
    | ns_ip          | 10.141.255.252    |
    | rev_include    | -                 |
    | version        | 4                 |
    | comment        |                   |
    +----------------+-------------------+

The name is used as a domain for DNS. All IP addresses to be defined later in Luna will inherit their properties from the network definition. Networks in Luna automatically check for IP address uniqueness in order to avoid IP address conflicts. All occupied IP addresses can be listed::

    # luna network show ipmi --reservedips | sort
    10.149.0.1:node001
    10.149.0.2:node002
    10.149.0.3:node003
    10.149.0.4:node004
    10.149.200.1:switch01
    10.149.250.1:pdu01
    10.149.255.254:controller


Luna can manage DNS zones by itself. After running ``luna cluster makedns``, a user will be able to resolve, for example, node001.ipmi and pdu01.ipmi hostnames. Luna will create reverse zones as well. If it is required to create additional records in DNS, like MX or SRV, ``--include`` and ``--rev_include`` options can be used.

Groups in Luna
~~~~~~~~~~~~~~

A key concept in Luna is that of groups. Most (after osimage) of the customizations in Luna are performed here. A group is a homogeneous set of nodes. They usually have the same role within the cluster, with a similar hardware configuration, software set, and are connected to the same networks. Usually, they are logically grouped to the same queue (or partition) in the scheduling system. It is possible to specify the same osimage for several groups and perform additional customizations on install.

Creating a group requires the osimage to be specified. A group can't exist without an image or connection to a network. It is assumed that nodes need to be installed via the network, as we are using a network provisioning tool::

    # luna group add --name new-compute-group --osimage new-compute --network cluster

    # luna group show new-compute-group
    +---------------+-------------------------------------------------+
    | Parameter     | Value                                           |
    +---------------+-------------------------------------------------+
    | name          | new-compute-group                               |
    | bmcsetup      | -                                               |
    | domain        | [cluster]                                       |
    | interfaces    | [BOOTIF]:[cluster]:10.141.0.0/16                |
    | osimage       | [new-compute]                                   |
    | partscript    | mount -t tmpfs tmpfs /sysroot                   |
    | postscript    | cat << EOF >> /sysroot/etc/fstab                |
    |               | tmpfs   /       tmpfs    defaults        0 0    |
    |               | EOF                                             |
    | prescript     |                                                 |
    | torrent_if    | -                                               |
    | comment       |                                                 |
    +---------------+-------------------------------------------------+

In addition it is possible to specify a management (IPMI/BMC) network::

    # luna group add --name new-compute-group --osimage new-compute --network cluster --bmcnetwork ipmi --bmcsetup bmcconfig

    # luna group show new-compute-group
    +---------------+-------------------------------------------------+
    | Parameter     | Value                                           |
    +---------------+-------------------------------------------------+
    | name          | new-compute-group                               |
    | bmcsetup      | [bmcconfig]                                     |
    | domain        | [cluster]                                       |
    | interfaces    | [BMC]:   [ipmi]:10.149.0.0/16                   |
    |               | [BOOTIF]:[cluster]:10.141.0.0/16                |
    | osimage       | [new-compute]                                   |
    | partscript    | mount -t tmpfs tmpfs /sysroot                   |
    | postscript    | cat << EOF >> /sysroot/etc/fstab                |
    |               | tmpfs   /       tmpfs    defaults        0 0    |
    |               | EOF                                             |
    | prescript     |                                                 |
    | torrent_if    | -                                               |
    | comment       |                                                 |
    +---------------+-------------------------------------------------+

In this case, the IPMI configuration will be enforced on install, configuring the IP address and credentials for remote power management via ``lpower``. This can be added, deleted, or changed later.

Please note the two interfaces BMC and BOOTIF on the example above.

    - BMC reflects the IPMI interface of the node. Applied config can be found in the ``ipmitool lan print`` output on the node.
    - BOOTIF is a synonym of the interface node connected to the network. Usually Luna operates with the actual names of interfaces, like eth0, em1, p2p1 or ib0. If BOOTIF is specified as the name, Luna tries to find the real name of the interface based on the MAC-address exposed by the node on boot.

To add nodes to the group simply run::

    # luna node add --name node001 --group new-compute-group


Configuring interfaces
~~~~~~~~~~~~~~~~~~~~

In simple cases, networking will just work. But sometimes a non-trivial configuration is necessary, in cases where bonding, bridging, or a VLAN config is required. This can be done with Luna.

First, it may be necessary to rename the interfaces::

    # luna group change new-compute-group --interface BOOTIF --rename bond0
    INFO:group.new-compute-group:No boot interface for nodes in the group configured. DHCP will be used during provisioning.

And add two more interfaces::

    # luna group change new-compute-group --interface eth0 --add
    # luna group change new-compute-group --interface eth1 --add

Then, change the configuration of the interfaces, as one would configure ``/etc/sysconfig/network-scripts/ifcfg-*`` files. To do so, specify the ``--edit`` argument::

    # luna group change new-compute-group --interface bond0 --edit

This will open an editor in which the configuration can be typed with regular ``ifcfg-*`` syntax. Optionally, the ``--edit`` flag accepts piping from STDIN::

    # cat << EOF | luna group change new-compute-group --interface bond0 --edit
    > TYPE=Bond
    > BONDING_MASTER=yes
    > BONDING_OPTS="mode=1"
    > EOF

    # cat << EOF | luna group change new-compute-group --interface eth0 --edit
    > MASTER=bond0
    > SLAVE=yes
    > EOF

    # cat << EOF | luna group change new-compute-group --interface eth1 --edit
    > MASTER=bond0
    > SLAVE=yes
    > EOF

Please note that it is unnecessary to specify ``NAME=`` and ``DEVICE=`` for interfaces; ``IPADDR=`` and ``PREFIX=`` will be added automatically on a per-node basis.


Scripts in groups
~~~~~~~~~~~~~~~~~

Sometimes the installation procedure needs to be altered to perform some tasks before or after the osimage is deployed. Customization scripts come into play here. Each group has 3: prescript, partscript, and postscript.

- ``prescript`` is performed before any other task of the installation procedure. Can be handy if we need to insert a non-standard kernel module for later use or check some hardware status.

- ``partscript`` creates partitions and prepares filesystems to unpack the tarball. Dracut expects that all needed files will be located in ``/sysroot`` to perform switch_root to boot the actual OS up. We need to create filesystems and mount them under ``/sysroot``. Also, partscript is a good place to check if the disk we are going to use for the OS is the proper one: check the size and hardware path of the disk.

- ``postscript`` is for finishing up installation: install bootloader on disk, perform some customization of the unpacked image, etc.

Some examples of the scripts can be found in ``man luna``.

By default, every group is created with the default partscript where the osimage will be placed in memory. This is a so-called "diskless" configuration. Any file on the local filesystems will not be touched or altered. Changing the partscript from default to the following example will convert a node from diskless to diskful::

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

Please note that it is not necessary to change the osimage in order to make a node diskful. The same image can be used, but instead of mounting the ramdisk to ``/sysroot``, /dev/sda2 is placed there.

To make a node self-contained, bootloader should be added and fstab changed to communiate to systemd where to find ``/``::

    mount -o bind /proc /sysroot/proc
    mount -o bind /dev /sysroot/dev
    chroot /sysroot /bin/bash -c "/usr/sbin/grub2-mkconfig \
        -o /boot/grub2/grub.cfg; /usr/sbin/grub2-install /dev/sda"
    chroot /sysroot /bin/bash -c \
        "echo '/dev/sda2 /     ext4 defaults 0 0' >> /etc/fstab"
    chroot /sysroot /bin/bash -c \
        "echo '/dev/sda1 /boot ext4 defaults 0 0' >> /etc/fstab"
    umount /sysroot/dev
    umount /sysroot/proc


To edit the script, simply run::

    # luna group change new-compute --partscript --edit

It will open the editor. In addition, it supports piping::

    # cat compute-part.txt | luna group change compute --partscript --edit

Other configurable items in Luna
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Switches must be configured for Luna to automatically discover nodes' MAC addresses. It is crucial to check if a switch provides information about learned MAC addresses vin SNMP::

    # snmpwalk -On -c public -v 1 SWITCH_IP .1.3.6.1.2.1.17.7.1.2.2.1

It should list something like::

    .1.3.6.1.2.1.17.7.1.2.2.1.2.1.24.102.218.96.27.201 = INTEGER: 210

The last 6 numbers is a MAC address in decimal format. See ``man luna`` for more information on how to decrypt it.

When Luna is able to get MAC addresses from switches, it will display them in ``luna cluster listmacs``.

Other devices present as ``otherdev`` in Luna. This class of configurable items will fill DNS records. For example, it is handy to resolve PDUs' hostnames.

The last item worthy of mention is ``bmcsetup``. It describes the IPMI/BMC settings for nodes: credentials and IPMI control channels.

Node management
~~~~~~~~~~~~~~~

As said, most of the tunables for nodes should be performed on a group level. However, several items need to be managed individually for each node. These are IP addresses, MAC address, and switch/port pair.

The MAC address is considered a unique identifier of the node. If not configured manually, it will be acquired based on the switch and port configuration. Another way of setting up the MAC address is to choose node name from the list during boot. If the MAC address is not known for the node, it will be looping in the boot menu.

IP address for a node is always configured from the network defined in the corresponding group. IP is always assigned on the interface if the network is configured for this interface on the group level and Luna controls this rule.

It is possible to change the group for a node and Luna does its best to preserve configured IP addresses. It can be tricky as the set of interfaces on the destination group might be different from that of the source group.

Further individual settings for node are ``--setupbmc`` and ``--service``. These are mostly relevant for debugging. The first allows disabling of attempts to configure BMC, as it is known this configuration might be flaky. ``--service`` tunable can be handy if an engineer needs to debug boot issues. Nodes in this mode will not try to run the install script, but will stay in the initrd stage, configure 2 consoles (Alt+F1, Alt+F2), and try to set up IP addresses and run ssh daemon. In addition, it can be used to inspect the hardware configuration of the node before setup and wiping of data on disks.

Another debug feature is a flag ``luna node show --script`` which accepts two options: ``boot`` and ``install``.

- ``--script boot`` shows the exact boot options node will use to fetch and run kernel and initrd.

- ``--script install`` provides a way to inspect the script that will be used to install the node. Combined with ``--service yes`` it is a good way to catch mistakes like unpaired parentheses or quotes in pre/part/post scripts.


Debug hints
~~~~~~~~~~~

Sometimes a node refuses to boot and it is hard to say why. To address the issue, first check which step of the boot process gets stuck.

There are several boot steps:

- PXE/iPXE

- Luna boot menu

- Initrd

- Install procedure

First check the status of ``node show`` to get an idea of where the issue is. If this status is empty, most likely the node hangs somewhere before or in the boot menu.

For PXE/iPXE issues, the first suspect is usually the firewall. Then, check if the node is able to get an IP address from the DHCP range: check ``/var/log/messages`` on the controller, lease file, and DHCP range in ``luna cluster show`` and ``/etc/dhcpd.conf``. Check if the node is able to download the ``luna_undionly.kpxe`` binary from the TFTP server using ``tftp get``.

If a node is able to show the boot menu (blue one), but refuses to go further, check if the node has a proper MAC address configured. If the node has the switch/port configured, check ``luna cluster listmacs`` output to make sure Luna is able to acquire MAC addresses from the switches. Sometimes it takes several minutes to download all MAC addresses from all switches. Once this is done, check nginx logs in ``/var/log/nginx``, ``/var/log/luna/lweb_tornado.log``, and ``--script boot`` script. Then, check permissions and content in the ``~luna/boot`` folder. Be sure ``osimage pack`` has been run before trying to boot the node.

If the node is able to fetch the kernel and initrd (this will be visible in nginx logs), the next step in debugging is to be sure the kernel is able to boot. This usually has no issues; those which may arise are typically limited to general Lunux issues - incompatible hardware, for example.

At this step, access to the console can be gained by pressing Alt+F1 or Alt+F2. Check if the node is pingable and accessible via ssh.

If Luna is unable to configure IP addresses, please check that the nodes have interfaces visible in ``ip a`` output. It might be a driver issue in this case. To fix it, add drivers to dracut. This can be done in ``/etc/dracut.conf.d`` in the osimage (don't forget to repack after changes!). In ``man dracut``, pay special attention to ``dracutmodules+=``, ``add_drivers+=`` and ``install_items+=``.

If the network is working but the node is unable to proceed with installation, check the nginx logs to be sure the node is trying to download the installation script. Check the output of ``--script install`` to see the script. Check ``journalctl -xe`` on the node and search for occurrences of ``Luna``. Check the content of the ``/luna`` folder on the node. It should at least contain the ``install.sh`` script. Later, it will contain ``*.torrent`` file. The next step is to check the tarball in ``/sysroot`` on the node. It should exist and be the same size as in ``~luna/torrents``. Inspect nginx logs for ``announce`` URLs. Pay attention to the ``peer_id=`` and ``downloaded=`` section. Records with ``peer_id=lunalunalunalunaluna`` are originating from the controller.

At this point, partscript should prepare ``/sysroot``, i.e. format and mount disks or mount ramdisk. If some issues arise here, be sure the desired filesystem appears in ``/proc/filesystems`` on the node. Otherwise, use ``filesystems+=`` for dracut in the osimage (and pack again).  Be sure there is enough space - 4G is absolute minimum. At some point during installation, the tarball itself and unpacked tarball will be present on the same filesystem, so a capacity of 2x the size of the osimage is required.

On this step, ``/sysroot`` should contain the same set of files as osimage configured for node. After ``postscript``, the Luna dracut module is ready to exit and give control to systemd boot procedures. If boot gets stuck, check that the filesystem was configured in the previous step. A common error is the failure to mount any filesystem to ``/sysroot`` and unpack content just in memory.

For more details about Luna boot internals, read ``doc/hints-n-tips/boot-process.md`` in Luna's repository.
