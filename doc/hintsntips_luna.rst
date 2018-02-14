
Hints and tips for a Luna installation
======================================


Setting up a compute node image
-------------------------------

.. note:: This chapter assumes that you are familiar with the TrinityX configuration tool and the configuration files that it uses. If not, please refer to the general :doc:`index` first.

TrinityX includes configuration files to create automatically a basic compute node images. When receiving a new cluster this task will have been done already by our engineers and the image will be integrated in your provisioning system, in that case Luna.


Cloning an existing image
~~~~~~~~~~~~~~~~~~~~~~~~~

The easiest way to get a new image for modifications is to clone an existing one. For example::

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

In some other cases you may prefer to start from a fresh image. In that case copy the existing playbook and change name of the image (``image_name`` variable and ``hosts`` target)::

    # cp compute.yml new-compute.yml
    # sed -i -e 's/compute/new-compute/' new-compute.yml

You might also want to customize your new image adding more roles. When you are done, run ``ansible-playbook``::

    # ansible-playbook new-compute.yml

To speed up the creation time it is possible to disable packing of the image. It is handy when you testing your changes::

    # ansible-playbook --skip-tags=wrapup-images  new-compute.yml


Modifying images and packing them
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As shown here is 2 ways of creating new images in TrinitX: manual and ansible-way. Same can be applied for modifying images. To do it manual you need to clone image with ``luna osimage clone`` and modify them as regular set of files or in chrooted environment.

Second approach is to use ansible to manage your images.

Couple of words about how to manually modify the content of the image. Luna has a tool called ``lchroot``. It is a wrapper around good old ``chroot`` tool, but with some additions and integration with Luna. In particular it mounts /dev, /proc, /sys filesystems on start and unmounts on exit. Please don't try to pack the image if you have ``lchroot`` session running. Packing the image will pack content of the mentioned service filesystems and this is probably not what you want.

The tool can also mock the kernel version allowing to install software which requires particular release::

    # uname -r
    3.10.0-693.17.1.el7.x86_64

    # lchroot new-compute
    IMAGE PATH: /trinity/images/new-compute
    chroot [root@new-compute /]$ uname -r
    3.10.0-693.5.2.el7.x86_64

Before packing image you might want to change kernel options or kernel version if you have several installed::

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

After customization is done it is important to pack the image to make changes available for nodes. Packing is a creating tarball, create torrent-file from it and adding it to Luna DB. Everything is being done automatically when ``luna osimage pack`` is executed::

    # luna osimage pack new-compute
    INFO:root:Creating tarball.
    INFO:root:Done.
    INFO:root:Creating torrent.
    INFO:root:Done.
    INFO:root:Copying kernel & packing inirtd.
    INFO:root:Done.


In TrinityX's playbook this task is being done by ``wrapup-images`` role::

    TASK [trinity/wrapup-images : Pack the image] **********************************
    changed: [new-compute.osimages.luna -> localhost]

Grabbing image from live node
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This method is handy when some software requires a hardware to be physically present on node to run its installation procedure. After installation is complete it is possible to sync files back to image. Before doing so it is worth to inspect ``--grab_exclude_list`` and ``--grab_filesystems`` options in order to limit amount of data to be synced. To check what needs to be synced ``--dry_run`` can be specified::

    # luna osimage grab new-compute --host node001 --dry_run
    INFO:luna.osimage.new-compute:Fetching / from node001
    INFO:luna.osimage.new-compute:Running command: /usr/bin/rsync -avxz -HAX -e "/usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" --progress --delete --exclude-from=/tmp/new-compute.excl_list.rsync.ybBx8D  --dry-run  root@node001:/ /trinity/images/new-compute/
    <...snip...>

Networks in Luna
~~~~~~~~~~~~~~~~

Networks in Luna have 3 main options: name, network itself and prefix::

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

Name is being used as domain for DNS. All IP addresses  which will be defined later in Luna inherit properties from network definition. Networks in Luna automatically check for IP address uniqueness in order to avoid IP address conflicts. All occupied IP addresses can be listed::

    # luna network show ipmi --reservedips | sort
    10.149.0.1:node001
    10.149.0.2:node002
    10.149.0.3:node003
    10.149.0.4:node004
    10.149.200.1:switch01
    10.149.250.1:pdu01
    10.149.255.254:controller


Luna can manage DNS zones by itself. So after running ``luna cluster makedns`` user will be able to resolve, for example, node001.ipmi and pdu01.ipmi hostnames. Luna will create reverse zones as well. If it is required to create additional records in DNS, like MX or SRV, ``--include`` and ``--rev_include`` options can be used.

Groups in Luna
~~~~~~~~~~~~~~

Groups in Luna are one of the key concept. Most (after osimage) of the customizations in Luna are being performed here. Group is a way to describe homogeneous set of nodes. They usually have same role within the cluster, have similar hardware configuration, software set and have networks connected to. Usually they are logically grouped to the same queue (or partition) in scheduling system. However it is possible to specify same osimage for several groups and perform additional customization on install.

Creatin group requires osimage to be specified. Group can't exist without image. Second mandatory parameter is network node is connected to. It is assuming that node need to be installed via network, otherwise it is make no much sense to use network provisioning tool::

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

In addition it is possible to specify management (IPMI/BMC) network::

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

In this case IPMI config will be enforced on install, making IP address and credentials configured for remote power management via ``lpower``. They can be added, deleted or changed later.

Please note two interfaces BMC and BOOTIF on the example above.

    - BMC reflects IPMI interface of the node. Applied config can be found in ``ipmitool lan print`` output on the node.
    - BOOTIF is a synonym of the interface node is connected to the network. Usually Luna operates with actual names of the interfaces, like eth0, em1, p2p1 or ib0. If BOOTIF is specified as the name, Luna tries to find the real name of the interface based on MAC-address node exposed on boot.

To add nodes to the group simply run::

    # luna node add --name node001 --group new-compute-group


Configing interfaces
~~~~~~~~~~~~~~~~~~~~

In simple cases networking will just work. But sometimes it is required to have non-trivial config where bonding, bridging or VLAN config need to be introduced. It is possible to do with Luna.

First you might need to rename interfaces::

    # luna group change new-compute-group --interface BOOTIF --rename bond0
    INFO:group.new-compute-group:No boot interface for nodes in the group configured. DHCP will be used during provisioning.

And add two more interfaces::

    # luna group change new-compute-group --interface eth0 --add
    # luna group change new-compute-group --interface eth1 --add

Then you need to change configuration of the interfaces, like if you would configure ``/etc/sysconfig/network-scripts/ifcfg-*`` files. To do so you can specify ``--edit`` argument::

    # luna group change new-compute-group --interface bond0 --edit

This will open editor for your convenience where you can type config with regular ``ifcfg-*`` syntax. Optionally ``--edit`` flag accepts piping from STDIN::

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

Please note that you don't need to specify ``NAME=`` and ``DEVICE=`` for interfaces; ``IPADDR=`` and ``PREFIX=`` will be added automatically on per-node basis.


Scripts in groups
~~~~~~~~~~~~~~~~~

Sometimes install procedure need to be altered to performs some tasks before or after tarball with osimage will be placed. Here is the place where customization scripts go into play. Each group has 3 of them: prescript, partscript and postscript.

- ``prescript`` is being performed before any other task of the installation procedure. Can be handy if we need to insert non-standard kernel module to use it later or check some hardware status.

- ``partscript`` is aimed to create partitions and prepare filesystems to unpack tarball. Dracut expects that all needed files will be located in ``/sysroot`` to perform switch_root to boot the actual OS up. So we need to create filesystems and mount them under ``/sysroot``. Also, partscript it is a good place to check if the disk we are going to use for OS is the proper one: check size and hardware path of the disk.

- ``postscript`` is for finishing up installation: install bootloader on disk, perform some customisation of the unpacked image, etc.

Some examples of the scripts can be found in ``man luna``.

By default every group is being created with default partscript where osimage will be placed in memory. This is so-called diskless configuration. Any file on local filesystems will not be touched or altered. Changing partscript from default to the following example will convert node from diskless to diskful::

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

Please note, that we do not need to change osimage anyhow to make node diskful. We are using the same image, but istead of mounting ramdisk to ``/sysroot`` we are putting /dev/sda2 there.

To make node self-contained we still need to add bootloader and change fstab to tell systemd where to find ``/``::

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


To edit script simply run::

    # luna group change new-compute --partscript --edit

It will open editor for you. In addition it supports piping::

    # cat compute-part.txt | luna group change compute --partscript --edit

Other configurable items in Luna
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Switches are required to be configured if you want to make Luna automatically discover nodes' MAC addresses. It is crucial to check if switch provides information about learned MAC addresses vin SNMP::

    # snmpwalk -On -c public -v 1 SWITCH_IP .1.3.6.1.2.1.17.7.1.2.2.1

It should list something like::

    .1.3.6.1.2.1.17.7.1.2.2.1.2.1.24.102.218.96.27.201 = INTEGER: 210

Last 6 numbers is some MAC address in decimal format. See ``man luna`` for more information how to decrypt it.

When Luna is able to get MAC addresses from switches it can display them in ``luna cluster listmacs``.

Other devices is present as ``otherdev`` in Luna. This class of configurable items persists to fill DNS records. For example it is handy to resolve PDUs' hostnames.

Last item need to mention is ``bmcsetup``. It describes IPMI/BMC settings for nodes: credentials and IPMI control channels.

Node management
~~~~~~~~~~~~~~~

As it was said most of the tunables for the node needs to be performed on a group level. However several of them need to be managed individually for each node. Those are IP addresses, MAC address and switch/port pair.

MAC address is considered as unique identifier of the node. If it is not configured manually it will be acquired based on switch and port configuration. Another way of setting up MAC address is to choose node nae from the list during boot. If MAC address is not known for the node, node will be looping in boot menu.

IP address for node is always configured from the network defined in corresponding group. IP is always assigned on interface if network is configured for this interface on group level and Luna controls this rule.

It is possible to change group for node and Luna does all its best to preserve configured IP addresses. It can be tricky as set of interfaces on destination group might be different from source group.

Another individual settings for node are ``--setupbmc`` and ``--service``. Those are introduced mostly for debug purposes. First allows to disable attempts of configuring BMC, as it is known this configuration might be flaky. ``--service`` tunable can be handy if engineer need to debug boot issues. Node in this mode will not try to run install script, but will stay in initrd stage, configure 2 consoles (Alt+F1, Alt+F2), will try to set up IP addresses and run ssh daemon. In addition it can be used to inspect hardware configuration of the node before setup and wiping all the data on disks.

Another debug feature is a flag ``luna node show --script`` it accepts two options ``boot`` and ``script``.

- ``--script boot`` shows the exact boot options node will use to fetch and run kernel and initrd.

- ``--script install`` provides a way to inspect the script will be used to install the node. Combined with ``--service yes`` it is a good way to catch mistakes like unpaired parentheses or quotes in pre/part/post scripts.


Debug hints
~~~~~~~~~~~

Sometimes node refuses to boot and it is hard to say why. To address the issue first need to check on which step of the boot process node gets stuck.

There are several boot steps:

- PXE/iPXE

- Luna boot menu

- Initrd

- Install procedure

First check status ``node show`` to get an idea where issue is. If status is empty more likely node hangs somewhere before or in boot menu.

For PXE/iPXE issues the first suspect usually firewall. Then you need to check if node is able to get IP address from DHCP range: check ``/var/log/messages`` on the controller, lease file and DHCP range in ``luna cluster show`` and ``/etc/dhcpd.conf``. Please check if node is able to download ``luna_undionly.kpxe`` binary from TFTP server using ``tftp get``.

If node is able to show boot menu (blue one), but refuses to go further it worth to check if node has proper MAC address configured. If node has switch/port configured you can check ``luna cluster listmacs`` output to make sure Luna is able to acquire learned MAC addresses from switch. Sometimes it takes several minutes to download all MAC addresses from all switches. Then you need to check nginx logs in ``/var/log/nginx``, ``/var/log/luna/lweb_tornado.log`` and ``--script boot`` script. Then check permissions and content in ``~luna/boot`` folder. Be sure you did run ``osimage pack`` before trying to boot node.

If node is able to fetch kernel and initrd (it will be visible in nginx logs) next step to debug is to be sure kernel is able to boot. No issues with this usually, but if any it is mostly general Lunux issues - incompatible hardware for example.

At this step you can get acces to the console pressing Alt+F1 or Alt+F2. You can also check if node is pingable and accessible via ssh.

If Luna is unable to configure IP addresses please check node have interfaces visible in ``ip a`` output. Might be a driver issue. To fix it please add drivers to dracut. This can be done in ``/etc/dracut.conf.d`` in the osimage (don't forget to repack after change!). In ``man dracut`` pay special attention to ``dracutmodules+=``, ``add_drivers+=`` and ``install_items+=``.

If network is working but node is unable to proceed with installation please check nginx logs to be sure node is trying to download install script. Check ``--script install`` output to see the script. Check ``journalctl -xe`` on the node and search for ``Luna`` occurrences. Check content of ``/luna`` folder on the node. It should contain ``install.sh`` script at least. Later it will contain ``*.torrent`` file. Next step is to check tarball in ``/sysroot`` on the node. It should exist and be the same size as in ``~luna/torrents``. Please inspect nginx logs for ``announce`` URLs. Pay attention to ``peer_id=`` and ``downloaded=`` section. Records with ``peer_id=lunalunalunalunaluna`` are going from controller.

At this point partscript should prepare ``/sysroot``, i.e. format and mount disks or mount ramdisk. If some issues are arising here, be sure you have desired filesystem in ``/proc/filesystems`` on the node. Otherwise use ``filesystems+=`` for dracut in osimage (and pack again).  Be sure you have enough space - 4G is absolute minimum. At some point during install, tarball itself and unpacked tarball will be present on the same filesystem, so 2x size of the osimage is required.

On this step ``/sysroot`` should contain the same set of files as osimage configured for node. After ``postscript`` Luna dracut module is ready to exit and give the control to systemd boot procedures. If boot gets stuck please check that you had filesystem configured on previous step. Common mistake is not to mount any filesystem to ``/sysroot`` and unpack content just in memory.

For more details about Luna boot internals feel free to read ``doc/hints-n-tips/boot-process.md`` in Luna's repository.
