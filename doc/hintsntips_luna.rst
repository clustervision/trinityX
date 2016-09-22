
Hints and tips for a Luna installation
======================================


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

